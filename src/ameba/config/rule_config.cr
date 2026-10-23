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
        property? enabled = !deprecated?
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

                {% elsif prop[:type] == Severity %}
                  builder.field("$ref", "#/$defs/Severity")
                  builder.field("default", {{ prop[:default].capitalize }})

                  {% default_set = true %}

                {% else %}
                  {% nodes = [prop[:default]] %}
                  {% nodes << "::Union(#{prop[:type]})".id if prop[:type] %}

                  # Hash defaults are written per key, within `properties`
                  {% default_set = prop[:default].is_a?(HashLiteral) || prop[:default].is_a?(NamedTupleLiteral) %}

                  json_schema_type(builder, {{ nodes.map { |node| "(#{node})".id }.splat }}, defaults: {{ default_set }})
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
    end

    # :nodoc:
    #
    # Writes the JSON schema matching all of the given *nodes*, each being
    # either a literal value, a constant, or a type wrapped in `::Union(...)`
    # (since `A | B` given as an argument is a `Call`). Nodes can be wrapped
    # in parentheses as well (since `[] of A, B` given as arguments is
    # a `Proc` type).
    #
    # Constants are described by their values (enum members by their types),
    # resolved one step at a time, by expanding this macro again, until
    # there are none left. The rest is handled by `json_schema_type_of`.
    #
    # With *defaults* set to `true`, the default value of each one of the
    # `properties` is written as well.
    #
    # NOTE: It needs to be called without a receiver, so that constants and
    # types are resolved lazily, from within the rule scope (which allows
    # referring to the ones defined after the rule class itself as well).
    macro json_schema_type(builder, *nodes, defaults = false)
      {% resolved_nodes = [] of ASTNode %}
      {% resolved = false %}

      {% for node in nodes %}
        {% node = node.expressions.last if node.is_a?(Expressions) %}

        {% if node.is_a?(Path) && (value = node.resolve?) && !value.is_a?(TypeNode) %}
          {% enum_type = node.names.size > 1 && parse_type(node.stringify.gsub(/::[^:]+$/, "")).resolve? %}
          {% if enum_type.is_a?(TypeNode) && enum_type < Enum %}
            {% node = "::Union(::#{enum_type})".id %}
          {% else %}
            {% node = value %}
          {% end %}
          {% resolved = true %}
        {% end %}

        {% resolved_nodes << node %}
      {% end %}

      {{ (resolved ? "json_schema_type" : "json_schema_type_of").id }}(
        {{ builder }},
        {{ resolved_nodes.map { |node| "(#{node})".id }.splat }},
        defaults: {{ defaults }},
      )
    end

    # :nodoc:
    #
    # Writes the JSON schema matching all of the given *nodes*, with all
    # of the constants already resolved by `json_schema_type`.
    #
    # Schemas of the nested `items`, `properties` and `additionalProperties`
    # are written by expanding `json_schema_type` again, one level at a time.
    #
    # Anything of an unknown type (method calls, types not supported by the
    # JSON schema) leaves the schema unconstrained.
    macro json_schema_type_of(builder, *nodes, defaults = false)
      {% json_types = [] of StringLiteral %}
      {% items = [] of ASTNode %}
      {% properties = {} of ASTNode => ArrayLiteral %}
      {% property_defaults = {} of ASTNode => ASTNode %}
      {% additional_properties = [] of ASTNode %}
      {% unconstrained = false %}

      # Symbols are autocasted into enum members, which are parsed from strings
      {%
        literal_json_types = {
          "StringLiteral"       => "string",
          "StringInterpolation" => "string",
          "SymbolLiteral"       => "string",
          "BoolLiteral"         => "boolean",
          "NumberLiteral"       => "number",
          "NilLiteral"          => "null",
        }
      %}

      {% for node in nodes %}
        {% node = node.expressions.last if node.is_a?(Expressions) %}

        {% if json_type = literal_json_types[node.class_name] %}
          {% json_types << json_type %}

        {% elsif node.is_a?(Generic) && node.name.stringify == "::Union" %}
          {% type = node.resolve %}

          {% for type in (type.union? ? type.union_types : [type]) %}
            {% if type == Nil %}
              {% json_types << "null" %}
            {% elsif type == Bool %}
              {% json_types << "boolean" %}
            {% elsif type <= Number %}
              {% json_types << "number" %}
            {% elsif type < Enum && type.annotation(Flags) %}
              {% json_types << "array" %}
              {% items << "::Union(::String)".id %}
            {% elsif type == String || type == ::Path || type == Time || type < Enum %}
              {% json_types << "string" %}
            {% elsif type <= Array || type <= Set || type <= Tuple %}
              {% json_types << "array" %}

              {% for type_var in type.type_vars %}
                {% items << "::Union(#{type_var})".id %}
              {% end %}
            {% elsif type <= Hash %}
              {% json_types << "object" %}

              {% additional_properties << "::Union(#{type.type_vars.last})".id %}
            {% elsif type <= NamedTuple %}
              {% json_types << "object" %}

              {% for key in type.keys %}
                {% properties[key.stringify] = (properties[key.stringify] || [] of ASTNode) + ["::Union(#{type[key]})".id] %}
              {% end %}
            {% else %}
              {% unconstrained = true %}
            {% end %}
          {% end %}

        {% elsif node.is_a?(ArrayLiteral) || node.is_a?(TupleLiteral) %}
          {% json_types << "array" %}

          {% for element in node %}
            {% items << element %}
          {% end %}
          {% if node.is_a?(ArrayLiteral) && node.of %}
            {% items << "::Union(#{node.of})".id %}
          {% end %}

        {% elsif node.is_a?(HashLiteral) || node.is_a?(NamedTupleLiteral) %}
          {% json_types << "object" %}

          {% value_type = node.is_a?(HashLiteral) && node.of_value %}
          {% value_type = "::Union(#{value_type})".id if value_type %}

          {% for key, value in node %}
            {% key = key.id.stringify unless key.is_a?(StringLiteral) || key.is_a?(StringInterpolation) %}
            {% key_nodes = [value] %}
            {% key_nodes << value_type if value_type %}

            {% properties[key] = (properties[key] || [] of ASTNode) + key_nodes %}
            {% property_defaults[key] = value if defaults %}
            {% additional_properties << value if node.is_a?(HashLiteral) %}
          {% end %}

          {% additional_properties << value_type if value_type %}

        {% else %}
          {% unconstrained = true %}
        {% end %}
      {% end %}

      {% if unconstrained %}
        # Hash defaults written per key would be lost otherwise
        {% if defaults && (hash = nodes.find { |node| node.is_a?(HashLiteral) || node.is_a?(NamedTupleLiteral) }) %}
          {{ builder }}.field("default", {{ hash }})
        {% end %}
      {% else %}
        # Duplicates are skipped, with `"null"` (if present) placed last
        {% nilable = json_types.includes?("null") %}
        {% json_types = json_types.reject(&.== "null").uniq %}
        {% json_types << "null" if nilable %}

        {% if json_types.size == 1 %}
          {{ builder }}.field("type", {{ json_types.first }})
        {% elsif !json_types.empty? %}
          {{ builder }}.string("type")
          {{ builder }}.array do
            {% for json_type in json_types %}
              {{ builder }}.string({{ json_type }})
            {% end %}
          end
        {% end %}

        {% unless items.empty? %}
          {{ builder }}.string("items")
          {{ builder }}.object do
            json_schema_type({{ builder }}, {{ items.map { |node| "(#{node})".id }.splat }})
          end
        {% end %}

        {% unless properties.empty? %}
          {{ builder }}.string("properties")
          {{ builder }}.object do
            {% for key, key_nodes in properties %}
              {{ builder }}.string({{ key }})
              {{ builder }}.object do
                json_schema_type({{ builder }}, {{ key_nodes.map { |node| "(#{node})".id }.splat }})

                {% if property_defaults.has_key?(key) %}
                  {{ builder }}.field("default", {{ property_defaults[key] }})
                {% end %}
              end
            {% end %}
          end
        {% end %}

        {% unless additional_properties.empty? %}
          {{ builder }}.string("additionalProperties")
          {{ builder }}.object do
            json_schema_type({{ builder }}, {{ additional_properties.map { |node| "(#{node})".id }.splat }})
          end
        {% end %}
      {% end %}
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
