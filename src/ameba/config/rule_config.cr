class Ameba::Config
  # :nodoc:
  module RuleConfig
    # Define rule properties
    macro properties(&block)
      {% calls = block.body.is_a?(Expressions) ? block.body.expressions : [block.body] %}
      {% properties = {} of MacroId => NamedTuple %}

      {%
        number_types = {
          :i8 => Int8, :i16 => Int16, :i32 => Int32, :i64 => Int64, :i128 => Int128,
          :u8 => UInt8, :u16 => UInt16, :u32 => UInt32, :u64 => UInt64, :u128 => UInt128,
          :f32 => Float32, :f64 => Float64,
        }
      %}

      {% for call in calls.select(&.is_a?(Call)) %}
        {% name = call.name.id %}
        {% key = name.camelcase.stringify %}
        {% value = call.args.first %}
        {% type = call.named_args && call.named_args.find(&.name.== "as".id) %}
        {% type = type.value if type %}
        {% converter = nil %}

        {% if key == "Severity" %}
          {% type = Severity %}
          {% converter = SeverityYamlConverter %}
        {% end %}

        # Types are given explicitly (when known), so that they are documented
        {% unless type %}
          {% if value.is_a?(BoolLiteral) %}
            {% type = Bool %}
          {% elsif value.is_a?(StringLiteral) || value.is_a?(StringInterpolation) %}
            {% type = String %}
          {% elsif value.is_a?(NumberLiteral) %}
            {% type = number_types[value.kind] %}
          {% end %}
        {% end %}

        {% properties[name] = {key: key, type: type} %}

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
        # Default values are read from the rule loaded with no configuration
        # given, since the ones written within `properties` can be autocasted
        # (like symbols into enum members)
        rule = new

        builder.string(rule_name)
        builder.object do
          builder.field("$ref", "#/$defs/BaseRule")
          builder.field("$comment", documentation_url)
          builder.field("title", rule_name)

          {% if properties["description".id] %}
            builder.field("description", rule.description)
          {% end %}

          builder.string("properties")
          builder.object do
            {% for prop_name, prop in properties %}
              {% unless prop_name == "description".id %}
                builder.string({{ prop[:key] }})
                builder.object do
                  {% if prop[:type] == Severity %}
                    builder.field("$ref", "#/$defs/Severity")
                    builder.field("default", rule.severity.to_s)
                  {% else %}
                    # Described by the type of its instance variable, within
                    # the rule being instantiated (which can be a subclass)
                    \{% begin %}
                      ::Ameba::Config::RuleConfig.json_schema_type(builder, \{{ @type }}, [{{ prop_name.symbolize }}], default: rule.@{{ prop_name }})
                    \{% end %}
                  {% end %}
                end
              {% end %}
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
    # Writes the JSON schema matching all of the types given by *paths*
    # within the *rule* type.
    #
    # Each path starts with the name of an instance variable, followed by
    # the steps leading to a type nested within its own, each one being
    # a tuple of the union member index, and the type variable index or
    # named tuple key (`nil` standing for the flags enum member names).
    # Nested types are never referred to by their names, which allows them
    # to be private, or defined after the rule class itself.
    #
    # Schemas of the nested `items`, `prefixItems`, `properties` and
    # `additionalProperties` are written by expanding this macro again,
    # one level at a time.
    #
    # Types not supported by the JSON schema leave it unconstrained.
    #
    # With *default* given, it is written as well, and so are the defaults
    # of each one of its keys (for hashes and named tuples).
    #
    # NOTE: It needs to be called from within a method body, so that the
    # instance variables of the *rule* are known.
    macro json_schema_type(builder, rule, *paths, default = nil)
      {% instance_vars = rule.resolve.instance_vars %}
      {% types = [] of TypeNode %}
      {% type_paths = [] of ArrayLiteral %}

      {% for path in paths %}
        {% type = instance_vars.find(&.name.== path.first.id).type %}

        {% for step in path[1..-1] %}
          {% member = type.union? ? type.union_types[step[0]] : type %}

          {% if step[1].is_a?(NilLiteral) %}
            {% type = ::String %}
          {% elsif step[1].is_a?(StringLiteral) %}
            {% type = member[step[1].id] %}
          {% else %}
            {% type = member.type_vars[step[1]] %}
          {% end %}
        {% end %}

        {% unless types.includes?(type) %}
          {% types << type %}
          {% type_paths << path %}
        {% end %}
      {% end %}

      {% json_types = [] of StringLiteral %}
      {% items = [] of ArrayLiteral %}
      {% tuples = [] of ArrayLiteral %}
      {% named_tuples = [] of TypeNode %}
      {% properties = {} of StringLiteral => ArrayLiteral %}
      {% additional_properties = [] of ArrayLiteral %}
      {% unconstrained = false %}

      {% for type, type_index in types %}
        {% path = type_paths[type_index] %}

        {% for member, index in (type.union? ? type.union_types : [type]) %}
          {% if member == ::Nil %}
            {% json_types << "null" %}
          {% elsif member == ::Bool %}
            {% json_types << "boolean" %}
          {% elsif member <= ::Int %}
            {% json_types << "integer" %}
          {% elsif member <= ::Float %}
            {% json_types << "number" %}
          {% elsif member < ::Enum && member.annotation(::Flags) %}
            # Flags enums are parsed from a sequence of member names
            {% json_types << "array" %}
            {% items << path + [{index, nil}] %}
          {% elsif member == ::String || member == ::Path || member == ::Time || member < ::Enum %}
            {% json_types << "string" %}
          {% elsif member <= ::Array || member <= ::Set %}
            {% json_types << "array" %}
            {% items << path + [{index, 0}] %}
          {% elsif member <= ::Tuple %}
            {% json_types << "array" %}
            {% tuples << member.type_vars.map_with_index { |_, i| path + [{index, i}] } %}
          {% elsif member <= ::Hash %}
            {% json_types << "object" %}
            {% additional_properties << path + [{index, 1}] %}
          {% elsif member <= ::NamedTuple %}
            {% json_types << "object" %}
            {% named_tuples << member %}

            {% for key in member.keys %}
              {% properties[key.stringify] = (properties[key.stringify] || [] of ArrayLiteral) + [path + [{index, key.stringify}]] %}
            {% end %}
          {% else %}
            {% unconstrained = true %}
          {% end %}
        {% end %}
      {% end %}

      # Tuples are described by position, unless mixed with other sequences
      {% positional = tuples.size == 1 && items.empty? %}
      {% unless positional %}
        {% for tuple in tuples %}
          {% items = items + tuple %}
        {% end %}
      {% end %}

      {% unless unconstrained %}
        # Duplicates (and integers within numbers) are skipped,
        # with `"null"` (if present) placed last
        {% nilable = json_types.includes?("null") %}
        {% json_types = json_types.reject(&.== "integer") if json_types.includes?("number") %}
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
            ::Ameba::Config::RuleConfig.json_schema_type({{ builder }}, {{ rule }}, {{ items.splat }})
          end
        {% end %}

        {% if positional %}
          {% tuple = tuples.first %}

          {% unless tuple.empty? %}
            {{ builder }}.string("prefixItems")
            {{ builder }}.array do
              {% for tuple_path in tuple %}
                {{ builder }}.object do
                  ::Ameba::Config::RuleConfig.json_schema_type({{ builder }}, {{ rule }}, {{ tuple_path }})
                end
              {% end %}
            end
          {% end %}

          # Tuples are parsed from sequences of their exact size
          {{ builder }}.field("minItems", {{ tuple.size }})
          {{ builder }}.field("maxItems", {{ tuple.size }})
        {% end %}

        {% hash_defaults = default && !additional_properties.empty? %}
        {% named_tuple_defaults = default && named_tuples.size == 1 %}

        {% if !properties.empty? || hash_defaults %}
          {{ builder }}.string("properties")
          {{ builder }}.object do
            {% for key, key_paths in properties %}
              {{ builder }}.string({{ key }})
              {{ builder }}.object do
                ::Ameba::Config::RuleConfig.json_schema_type({{ builder }}, {{ rule }}, {{ key_paths.splat }})

                {% if named_tuple_defaults %}
                  if (%named_tuple = {{ default }}).is_a?(NamedTuple)
                    {{ builder }}.field("default", %named_tuple[{{ key.id.symbolize }}])
                  end
                {% end %}
              end
            {% end %}

            {% if hash_defaults %}
              if (%hash = {{ default }}).is_a?(Hash)
                %hash.each do |%key, %value|
                  {{ builder }}.string(%key.to_s)
                  {{ builder }}.object do
                    ::Ameba::Config::RuleConfig.json_schema_type({{ builder }}, {{ rule }}, {{ additional_properties.splat }})

                    {{ builder }}.field("default", %value)
                  end
                end
              end
            {% end %}
          end
        {% end %}

        # Named tuples are parsed only when all of their non-nilable keys are present
        {% if named_tuples.size == 1 && additional_properties.empty? %}
          {% required = named_tuples.first.keys.reject { |key| named_tuples.first[key].nilable? } %}

          {% unless required.empty? %}
            {{ builder }}.string("required")
            {{ builder }}.array do
              {% for key in required %}
                {{ builder }}.string({{ key.stringify }})
              {% end %}
            end
          {% end %}
        {% end %}

        {% unless additional_properties.empty? %}
          {{ builder }}.string("additionalProperties")
          {{ builder }}.object do
            ::Ameba::Config::RuleConfig.json_schema_type({{ builder }}, {{ rule }}, {{ additional_properties.splat }})
          end
        {% end %}
      {% end %}

      {% if default && !additional_properties.empty? %}
        # Hash keys are written the same way as within `properties`
        # (since not all of them can be serialized as JSON object keys)
        if (%hash = {{ default }}).is_a?(Hash)
          {{ builder }}.string("default")
          {{ builder }}.object do
            %hash.each do |%key, %value|
              {{ builder }}.field(%key.to_s, %value)
            end
          end
        else
          {{ builder }}.field("default", %hash)
        end
      {% elsif default %}
        {{ builder }}.field("default", {{ default }})
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
