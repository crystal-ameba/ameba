class Ameba::Config
  # :nodoc:
  module RuleConfig
    # Marks the instance variables of the rule properties.
    #
    # - *key*: the key of the property within the YAML config
    # - *built_in*: `true` if the property is defined implicitly by
    #   `properties` (like `Enabled`), rather than within the rule
    # - *base*: `true` if the property is common to all of the rules
    #   (like `Enabled`, even if defined within the rule)
    # - *base_default*: the default value of the *base* property,
    #   common to all of the rules (if any)
    annotation Property
    end

    # Marks the rules with properties defined by `properties`.
    annotation Properties
    end

    # Properties defined implicitly by `properties`, unless defined within
    # the rule, which then uses their converter (and type, unless given
    # or inferred from the value).
    #
    # The ones with *base* set to `true` are common to all of the rules,
    # with their *base_default* values (if any). Values are given as code,
    # evaluated within the rule.
    BUILT_IN_PROPERTIES = [
      {name: "description", type: "String?"},
      {name: "since_version", type: "String?", base: true},
      {name: "enabled", value: "!deprecated?", type: "Bool", base: true, base_default: "true"},
      {
        name:         "severity",
        value:        "default_severity",
        type:         "::Ameba::Severity",
        converter:    "::Ameba::SeverityYamlConverter",
        base:         true,
        base_default: "::Ameba::Rule::Base.default_severity",
      },
      {name: "excluded", type: "Set(String)?", base: true},
    ]

    # Describes a rule property, see `.property_definitions`.
    struct PropertyDefinition
      # Returns the property name, e.g. `max_length`.
      getter name : String

      # Returns the property key within the YAML config, e.g. `MaxLength`.
      getter key : String

      # Returns the property type, e.g. `Int32`.
      getter type : String

      # Returns the property default value.
      getter default : YAML::Any

      # Returns `true` if the property is defined implicitly by `properties`
      # (like `Enabled`), rather than within the rule.
      getter? built_in : Bool

      def initialize(*, @name, @key, @type, @default, @built_in = false)
      end
    end

    # Define rule properties
    macro properties(&block)
      {%
        if owner = ([@type] + @type.ancestors).find(&.annotation(::Ameba::Config::RuleConfig::Properties))
          block.raise("Rule properties are already defined within `#{owner}`")
        end

        calls = block.body.is_a?(Expressions) ? block.body.expressions : [block.body]
        calls = calls.reject(&.is_a?(Nop))

        number_types = {
          :i8 => Int8, :i16 => Int16, :i32 => Int32, :i64 => Int64, :i128 => Int128,
          :u8 => UInt8, :u16 => UInt16, :u32 => UInt32, :u64 => UInt64, :u128 => UInt128,
          :f32 => Float32, :f64 => Float64,
        }

        built_ins = ::Ameba::Config::RuleConfig::BUILT_IN_PROPERTIES.map do |built_in|
          {
            name:         built_in[:name].id,
            value:        built_in[:value] && built_in[:value].id,
            type:         parse_type(built_in[:type]).resolve,
            type_name:    built_in[:type],
            converter:    built_in[:converter] && parse_type(built_in[:converter]),
            base:         built_in[:base] == true,
            base_default: built_in[:base_default] && built_in[:base_default].id,
          }
        end

        definitions = calls.map do |call|
          if !call.is_a?(Call) || call.receiver || call.args.size != 1 || call.block || call.block_arg || !(call.name =~ /\A[a-z_][a-z0-9_]*\z/)
            call.raise("Rule properties are expected to be defined as `name value` (optionally followed by `as: Type`), not: `#{call}`")
          end

          type = nil

          if named_args = call.named_args
            named_args.each do |named_arg|
              if named_arg.name == "as".id
                type = named_arg.value
              else
                named_arg.raise("Unknown option `#{named_arg.name}` of rule property `#{call.name}` (expected `as`)")
              end
            end
          end

          built_in = built_ins.find(&.[:name].== call.name.id)

          {
            call:               call,
            name:               call.name.id,
            value:              call.args.first,
            type:               type,
            fallback_type:      built_in && built_in[:type],
            fallback_type_name: built_in && built_in[:type_name],
            converter:          built_in && built_in[:converter],
            built_in:           false,
            base:               built_in && built_in[:base],
            base_default:       built_in && built_in[:base_default],
          }
        end

        # Built-in properties go first, so that the rule properties
        # conflicting with them are reported
        built_ins = built_ins
          .reject { |built_in| definitions.any?(&.[:name].== built_in[:name]) }
          .map do |built_in|
            {
              call:               nil,
              name:               built_in[:name],
              value:              built_in[:value],
              type:               built_in[:type],
              fallback_type:      nil,
              fallback_type_name: nil,
              converter:          built_in[:converter],
              built_in:           true,
              base:               built_in[:base],
              base_default:       built_in[:base_default],
            }
          end

        properties = {} of MacroId => NamedTuple
      %}

      {% for definition in built_ins + definitions %}
        {%
          call = definition[:call]
          name = definition[:name]
          key = name.camelcase.stringify
          value = definition[:value]
          converter = definition[:converter]

          # Types are given explicitly (when known), so that they are documented
          type = definition[:type]
          type ||=
            if value.is_a?(BoolLiteral)
              Bool
            elsif value.is_a?(StringLiteral) || value.is_a?(StringInterpolation)
              String
            elsif value.is_a?(NumberLiteral)
              number_types[value.kind]
            end

          # Types given with `as:` are only their paths, so they're resolved
          # (unless defined later, like the aliases defined after the rule)
          if type && !type.is_a?(TypeNode)
            type = parse_type(type.stringify).resolve? || type
          end

          # Built-in properties keep their types, when defined within the rule
          if fallback_type = definition[:fallback_type]
            if !type
              type = fallback_type
            elsif type.is_a?(TypeNode) && !(type <= fallback_type)
              call.raise("Rule property `#{name}` is expected to be of the `#{definition[:fallback_type_name].id}` type (as the built-in one), not `#{type}`")
            end
          end

          getter = type == Bool ? "#{name}?".id : name

          if properties[name]
            call.raise("Rule property `#{name}` is already defined")
          elsif same_key_name = properties.keys.find { |other| properties[other][:key] == key }
            call.raise("Rule property `#{name}` would be configured with the same `#{key.id}` key as `#{same_key_name}`")
          elsif !definition[:built_in] && @type.has_method?(getter)
            call.raise("Rule property `#{name}` would override the `#{getter}` method of `#{@type}`")
          end

          properties[name] = {key: key}
        %}

        @[::Ameba::Config::RuleConfig::Property(
          key: {{ key }},
          built_in: {{ definition[:built_in] }},
          base: {{ definition[:base] == true }},
          base_default: {{ definition[:base_default] }},
        )]
        @[YAML::Field(key: {{ key }}, converter: {{ converter }})]

        # Declared with the type as given (if so), since resolved types are
        # referred to by their full names, which fails for the private ones
        {% declared_type = definition[:type] || type %}
        {% if type == Bool %}
          property? {{ name }}{{ " : #{declared_type}".id if declared_type }} = {{ value }}
        {% else %}
          property {{ name }}{{ " : #{declared_type}".id if declared_type }} = {{ value }}
        {% end %}
      {% end %}

      @[::Ameba::Config::RuleConfig::Properties]
      {% if @type.abstract? %}abstract {% end %}class ::{{ @type }}
      end

      def since_version : SemanticVersion?
        if version = @since_version
          SemanticVersion.parse(version)
        end
      end
    end

    # Returns the values of the rule properties, by their YAML keys,
    # written the same way as within the YAML config.
    def property_values : Hash(String, YAML::Any)
      {% begin %}
        values = {} of String => YAML::Any

        {% for ivar in @type.instance_vars %}
          {% if property = ivar.annotation(::Ameba::Config::RuleConfig::Property) %}
            {% field = ivar.annotation(::YAML::Field) %}

            values[{{ property[:key] }}] =
              ::Ameba::Config::RuleConfig.to_yaml_any(@{{ ivar.name }}, {{ field[:converter] }})
          {% end %}
        {% end %}

        values
      {% end %}
    end

    # :nodoc:
    def self.to_yaml_any(value, converter : Nil) : YAML::Any
      to_yaml_any { |builder| value.to_yaml(builder) }
    end

    # :ditto:
    def self.to_yaml_any(value, converter) : YAML::Any
      to_yaml_any { |builder| converter.to_yaml(value, builder) }
    end

    private def self.to_yaml_any(& : YAML::Nodes::Builder ->) : YAML::Any
      nodes = YAML::Nodes::Builder.new
      yield nodes

      yaml = String.build do |io|
        YAML.build(io) do |builder|
          nodes.document.to_yaml(builder)
        end
      end
      YAML.parse(yaml)
    end

    macro included
      # Returns the definitions of the rule properties, with their defaults
      # read from the rule loaded with no configuration given.
      #
      # NOTE: Abstract rules can't be loaded, and so their properties
      # can't be described either.
      def self.property_definitions : Array(::Ameba::Config::RuleConfig::PropertyDefinition)
        \{% if @type.abstract? %}
          raise "Properties of the abstract rule `#{name}` can't be described"
        \{% else %}
          defaults = new.property_values

          [
            \{% for ivar in @type.instance_vars %}
              \{% if property = ivar.annotation(::Ameba::Config::RuleConfig::Property) %}
                \{% key = property[:key] %}

                ::Ameba::Config::RuleConfig::PropertyDefinition.new(
                  name: \{{ ivar.name.stringify }},
                  key: \{{ key }},
                  type: \{{ ivar.type.union? ? ivar.type.union_types.join(" | ") : ivar.type.stringify }},
                  default: defaults[\{{ key }}],
                  built_in: \{{ property[:built_in] == true }},
                ),
              \{% end %}
            \{% end %}
          ] of ::Ameba::Config::RuleConfig::PropertyDefinition
        \{% end %}
      end

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
          if (raw = config.try(&.raw)).is_a?(Hash)
            yaml = raw[rule_name]?.try(&.to_yaml)
          end
          from_yaml(yaml || "{}")
        end
      end
    end
  end
end
