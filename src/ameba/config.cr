require "semantic_version"
require "yaml"
require "ecr/processor"

require "./glob_utils"
require "./config/*"

# A configuration entry for `Ameba::Runner`.
#
# Config can be loaded from configuration YAML file and adjusted.
#
# ```
# config = Config.load
# config.formatter = my_formatter
# ```
class Ameba::Config
  extend Loader
  include GlobUtils

  AVAILABLE_FORMATTERS = {
    progress:         Formatter::DotFormatter,
    todo:             Formatter::TODOFormatter,
    flycheck:         Formatter::FlycheckFormatter,
    silent:           Formatter::BaseFormatter,
    disabled:         Formatter::DisabledFormatter,
    json:             Formatter::JSONFormatter,
    "github-actions": Formatter::GitHubActionsFormatter,
  }

  DEFAULT_EXCLUDED = Set{"lib"}
  DEFAULT_GLOBS    = Set{"**/*.{cr,ecr}"}

  getter rules : Array(Rule::Base)
  property severity = Severity::Convention

  # Returns a root directory to be used by `Ameba::Runner`.
  property root : Path { Path[Dir.current] }

  # Returns an ameba version to be used by `Ameba::Runner`.
  property version : SemanticVersion?

  # Sets version from string.
  #
  # ```
  # config = Ameba::Config.load
  # config.version = "1.6.0"
  # ```
  def version=(version : String)
    @version = SemanticVersion.parse(version)
  end

  # Returns a formatter to be used while inspecting files.
  # If formatter is not set, it will return default formatter.
  #
  # ```
  # config = Ameba::Config.load
  # config.formatter = custom_formatter
  # config.formatter
  # ```
  property formatter : Formatter::BaseFormatter do
    Formatter::DotFormatter.new
  end

  # Sets formatter by name.
  #
  # ```
  # config = Ameba::Config.load
  # config.formatter = :progress
  # ```
  def formatter=(name : String | Symbol)
    unless formatter = AVAILABLE_FORMATTERS[name]?
      raise "Unknown formatter `#{name}`. Use one of #{Config.formatter_names}."
    end
    @formatter = formatter.new
  end

  # Returns a list of paths (with wildcards) to files.
  # Represents a list of sources to be inspected.
  # If globs are not set, it will return default list of files.
  #
  # ```
  # config = Ameba::Config.load
  # config.globs = Set{"**/*.cr"}
  # config.globs
  # ```
  property globs : Set(String)

  # Represents a list of paths to exclude from globs.
  # Can have wildcards.
  #
  # ```
  # config = Ameba::Config.load
  # config.excluded = Set{"spec", "src/server/*.cr"}
  # ```
  property excluded : Set(String)

  # Returns `true` if correctable issues should be autocorrected.
  property? autocorrect = false

  # Returns a filename if reading source file from STDIN.
  property stdin_filename : String?

  @rule_groups : Hash(String, Array(Rule::Base))

  # Creates a new instance of `Ameba::Config` based on YAML parameters.
  #
  # `Config.load` uses this constructor to instantiate new config by YAML file.
  protected def self.new(config : YAML::Any, root = nil)
    config = YAML.parse("{}") if config.raw.nil?
    config.raw.is_a?(Hash) ||
      raise "Invalid config file format"

    rules = Rule.rules.map &.new(config).as(Rule::Base)

    new(
      rules: rules,
      root: root,
      excluded: load_array_section(config, "Excluded", DEFAULT_EXCLUDED.dup).to_set,
      globs: load_array_section(config, "Globs", DEFAULT_GLOBS.dup).to_set,
      version: load_string_key(config, "Version"),
      formatter: load_string_key(config, "Formatter", "Name"),
    )
  end

  protected def initialize(
    *,
    @rules = [] of Rule::Base,
    @severity : Severity = :convention,
    @root = nil,
    @globs = Set(String).new,
    @excluded = Set(String).new,
    @autocorrect = false,
    @stdin_filename = nil,
    version = nil,
    formatter = nil,
  )
    @rule_groups = @rules.group_by &.group

    if version
      self.version = version
    end
    if formatter
      self.formatter = formatter
    end
  end

  def self.formatter_names
    AVAILABLE_FORMATTERS.keys.join('|')
  end

  # Returns a list of sources matching globs and excluded sections.
  #
  # ```
  # config = Ameba::Config.load
  # config.sources # => list of default sources
  # config.globs = Set{"**/*.cr", "**/*.ecr"}
  # config.excluded = Set{"spec"}
  # config.sources # => list of sources pointing to files found by the wildcards
  # ```
  def sources
    if file = stdin_filename
      [Source.new(STDIN.gets_to_end, file)]
    else
      files.map do |path|
        Source.new(File.read(path), path)
      end
    end
  end

  # Returns a list of files matching globs and excluded sections.
  #
  # ```
  # config = Ameba::Config.load
  # config.files # => list of default files
  # config.globs = Set{"**/*.cr", "**/*.ecr"}
  # config.excluded = Set{"spec"}
  # config.files # => list of files found by the wildcards
  # ```
  def files
    find_files_by_globs(globs, root) - find_files_by_globs(excluded, root)
  end

  # Updates rule properties.
  #
  # ```
  # config = Ameba::Config.load
  # config.update_rule "MyRuleName", enabled: false
  # ```
  def update_rule(name, enabled = true, excluded = nil)
    rule = @rules.find(&.name.==(name))
    raise ArgumentError.new("Rule `#{name}` does not exist") unless rule

    rule
      .tap(&.enabled = enabled)
      .tap(&.excluded = excluded.try &.to_set)
  end

  # Updates rules properties.
  #
  # ```
  # config = Ameba::Config.load
  # config.update_rules %w[Rule1 Rule2], enabled: true
  # ```
  #
  # also it allows to update groups of rules:
  #
  # ```
  # config.update_rules %w[Group1 Group2], enabled: true
  # ```
  def update_rules(names : Enumerable(String), enabled = true, excluded = nil)
    excluded = excluded.try &.to_set

    names.each do |name|
      if rules = @rule_groups[name]?
        rules.each do |rule|
          rule.enabled = enabled
          rule.excluded = excluded
        end
      else
        update_rule name, enabled, excluded
      end
    end
  end

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
