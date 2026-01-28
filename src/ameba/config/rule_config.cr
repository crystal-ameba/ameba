class Ameba::Config
  # :nodoc:
  module RuleConfig
    # Define rule properties
    macro properties(&block)
      {% definitions = [] of NamedTuple %}

      {% if (prop = block.body).is_a? Call %}
        {% if (named_args = prop.named_args) && (type = named_args.select(&.name.== "as".id).first) %}
          {% definitions << {var: prop.name, value: prop.args.first, type: type.value} %}
        {% else %}
          {% definitions << {var: prop.name, value: prop.args.first} %}
        {% end %}
      {% elsif block.body.is_a? Expressions %}
        {% for prop in block.body.expressions %}
          {% if prop.is_a? Call %}
            {% if (named_args = prop.named_args) && (type = named_args.select(&.name.== "as".id).first) %}
              {% definitions << {var: prop.name, value: prop.args.first, type: type.value} %}
            {% else %}
              {% definitions << {var: prop.name, value: prop.args.first} %}
            {% end %}
          {% end %}
        {% end %}
      {% end %}

      {% properties = {} of MacroId => NamedTuple %}
      {% for df in definitions %}
        {% name = df[:var].id %}
        {% key = name.camelcase.stringify %}
        {% value = df[:value] %}
        {% type = df[:type] %}
        {% converter = nil %}

        {% if key == "Severity" %}
          {% type = Severity %}
          {% converter = SeverityYamlConverter %}
        {% end %}

        {% unless type %}
          {% if value.is_a?(BoolLiteral) %}
            {% type = Bool %}
          {% elsif value.is_a?(StringLiteral) || value.is_a?(StringInterpolation) %}
            {% type = String %}
          {% elsif value.is_a?(NumberLiteral) %}
            {% if value.kind == :i32 %}
              {% type = Int32 %}
            {% elsif value.kind == :i64 %}
              {% type = Int64 %}
            {% elsif value.kind == :i128 %}
              {% type = Int128 %}
            {% elsif value.kind == :f32 %}
              {% type = Float32 %}
            {% elsif value.kind == :f64 %}
              {% type = Float64 %}
            {% end %}
          {% end %}
        {% end %}

        {% properties[name] = {key: key, default: value, type: type, converter: converter} %}

        @[YAML::Field(key: {{ key }}, converter: {{ converter }})]
        {% if type == Bool %}
          property? {{ name }}{{ " : #{type}".id if type }} = {{ value }}
        {% else %}
          property {{ name }}{{ " : #{type}".id if type }} = {{ value }}
        {% end %}
      {% end %}

      {% unless properties["enabled".id] %}
        @[YAML::Field(key: "Enabled")]
        property? enabled = true
      {% end %}

      {% unless properties["severity".id] %}
        @[YAML::Field(key: "Severity", converter: Ameba::SeverityYamlConverter)]
        property severity = {{ @type }}.default_severity
      {% end %}

      {% unless properties["excluded".id] %}
        @[YAML::Field(key: "Excluded")]
        property excluded : Set(String)?
      {% end %}

      {% unless properties["since_version".id] %}
        @[YAML::Field(key: "SinceVersion")]
        property since_version : String?
      {% end %}

      def since_version : SemanticVersion?
        if version = @since_version
          SemanticVersion.parse(version)
        end
      end

      def self.to_json_schema(builder : JSON::Builder) : Nil
        builder.string(rule_name)
        builder.object do
          builder.field("$ref", "#/$defs/BaseRule")
          builder.field("$comment", documentation_url)
          builder.field("title", rule_name)

          {% if description = properties["description".id] %}
            builder.field("description", {{ description[:default] }})
          {% end %}

          {%
            serializable_props =
              properties.to_a.reject { |(key, _)| key == "description" }
          %}

          builder.string("properties")
          builder.object do
            {% for prop in serializable_props %}
              {% default_set = false %}

              {% prop_name, prop = prop %}
              {% prop_stringified = prop[:type].stringify %}

              builder.string({{ prop[:key] }})
              builder.object do
                {% if prop[:type] == Bool %}
                  builder.field("type", "boolean")

                {% elsif prop[:type] == String %}
                  builder.field("type", "string")

                {% elsif prop_stringified == "::Union(String, ::Nil)" %}
                  builder.string("type")
                  builder.array do
                    builder.string("string")
                    builder.string("null")
                  end

                {% elsif prop_stringified =~ /^(Int|Float)\d+$/ %}
                  builder.field("type", "number")

                {% elsif prop_stringified =~ /^::Union\((Int|Float)\d+, ::Nil\)$/ %}
                  builder.string("type")
                  builder.array do
                    builder.string("number")
                    builder.string("null")
                  end

                {% elsif prop[:default].is_a?(ArrayLiteral) %}
                  builder.field("type", "array")

                  builder.string("items")
                  builder.object do
                    # TODO: Implement type validation for array items
                    builder.field("type", "string")
                  end

                {% elsif prop[:default].is_a?(HashLiteral) %}
                  builder.field("type", "object")

                  builder.string("properties")
                  builder.object do
                    {% for pr in prop[:default] %}
                      builder.string({{ pr }})
                      builder.object do
                        # TODO: Implement type validation for object properties
                        builder.field("type", "string")
                        builder.field("default", {{ prop[:default][pr] }})
                      end
                    {% end %}
                  end
                  {% default_set = true %}

                {% elsif prop[:type] == Severity %}
                  builder.field("$ref", "#/$defs/Severity")
                  builder.field("default", {{ prop[:default].capitalize }})

                  {% default_set = true %}

                {% else %}
                  {% raise "Unhandled schema type for #{prop}" %}
                {% end %}

                {% unless default_set %}
                  builder.field("default", {{ prop[:default] }})
                {% end %}
              end
            {% end %}

            {% unless properties["severity".id] %}
              unless default_severity == Rule::Base.default_severity
                builder.string("Severity")
                builder.object do
                  builder.field("$ref", "#/$defs/Severity")
                  builder.field("default", default_severity.to_s)
                end
              end
            {% end %}
          end
        end
      end

      def self.to_sarif(builder : JSON::Builder) : Nil
        {%
          serializable_props = properties.to_a.reject do |(key, prop)|
            !prop[:default] || {"description", "enabled", "severity", "since_version"}.includes?(key.stringify)
          end
        %}

        builder.object do
          {% for prop in serializable_props %}
            {% prop_name, prop = prop %}

            builder.field({{ prop_name.stringify }}, {{ prop[:default] }})
          {% end %}
        end
      end
    end

    macro included
      GROUP_SEVERITY = {
        Lint:        Ameba::Severity::Warning,
        Metrics:     Ameba::Severity::Warning,
        Performance: Ameba::Severity::Warning,
      }

      class_getter default_severity : Ameba::Severity do
        GROUP_SEVERITY[group_name]? || Ameba::Severity::Convention
      end

      macro inherited
        include YAML::Serializable
        include YAML::Serializable::Strict

        def self.new(config = nil)
          if (raw = config.try &.raw).is_a?(Hash)
            yaml = raw[rule_name]?.try &.to_yaml
          end
          from_yaml yaml || "{}"
        end
      end
    end
  end
end
