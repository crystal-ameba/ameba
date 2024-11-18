require "yaml"
require "./glob_utils"

# A configuration entry for `Ameba::Runner`.
#
# Config can be loaded from configuration YAML file and adjusted.
#
# ```
# config = Config.load
# config.formatter = my_formatter
# ```
#
# By default config loads `.ameba.yml` file located in a current
# working directory.
#
# If it cannot be found until reaching the root directory, then it will be
# searched for in the user’s global config locations, which consists of a
# dotfile or a config file inside the XDG Base Directory specification.
#
# - `~/.ameba.yml`
# - `$XDG_CONFIG_HOME/ameba/config.yml` (expands to `~/.config/ameba/config.yml`
#   if `$XDG_CONFIG_HOME` is not set)
#
# If both files exist, the dotfile will be selected.
#
# As an example, if Ameba is invoked from inside `/path/to/project/lib/utils`,
# then it will use the config as specified inside the first of the following files:
#
# - `/path/to/project/lib/utils/.ameba.yml`
# - `/path/to/project/lib/.ameba.yml`
# - `/path/to/project/.ameba.yml`
# - `/path/to/.ameba.yml`
# - `/path/.ameba.yml`
# - `/.ameba.yml`
# - `~/.ameba.yml`
# - `~/.config/ameba/config.yml`
class Ameba::Config
  include GlobUtils

  AVAILABLE_FORMATTERS = {
    progress: Formatter::DotFormatter,
    todo:     Formatter::TODOFormatter,
    flycheck: Formatter::FlycheckFormatter,
    silent:   Formatter::BaseFormatter,
    disabled: Formatter::DisabledFormatter,
    json:     Formatter::JSONFormatter,
  }

  XDG_CONFIG_HOME = ENV.fetch("XDG_CONFIG_HOME", "~/.config")

  FILENAME      = ".ameba.yml"
  DEFAULT_PATH  = Path[Dir.current] / FILENAME
  DEFAULT_PATHS = {
    Path["~"] / FILENAME,
    Path[XDG_CONFIG_HOME] / "ameba/config.yml",
  }

  DEFAULT_GLOBS = %w(
    **/*.cr
    !lib
  )

  getter rules : Array(Rule::Base)
  property severity = Severity::Convention

  # Returns a list of paths (with wildcards) to files.
  # Represents a list of sources to be inspected.
  # If globs are not set, it will return default list of files.
  #
  # ```
  # config = Ameba::Config.load
  # config.globs = ["**/*.cr"]
  # config.globs
  # ```
  property globs : Array(String)

  # Represents a list of paths to exclude from globs.
  # Can have wildcards.
  #
  # ```
  # config = Ameba::Config.load
  # config.excluded = ["spec", "src/server/*.cr"]
  # ```
  property excluded : Array(String)

  # Returns `true` if correctable issues should be autocorrected.
  property? autocorrect = false

  # Returns a filename if reading source file from STDIN.
  property stdin_filename : String?

  @rule_groups : Hash(String, Array(Rule::Base))

  # Creates a new instance of `Ameba::Config` based on YAML parameters.
  #
  # `Config.load` uses this constructor to instantiate new config by YAML file.
  protected def initialize(config : YAML::Any)
    if config.raw.nil?
      config = YAML.parse("{}")
    elsif !config.raw.is_a?(Hash)
      raise "Invalid config file format"
    end
    @rules = Rule.rules.map &.new(config).as(Rule::Base)
    @rule_groups = @rules.group_by &.group
    @excluded = load_array_section(config, "Excluded")
    @globs = load_array_section(config, "Globs", DEFAULT_GLOBS)

    if formatter_name = load_formatter_name(config)
      self.formatter = formatter_name
    end
  end

  # Loads YAML configuration file by `path`.
  #
  # ```
  # config = Ameba::Config.load
  # ```
  def self.load(path = nil, colors = true, skip_reading_config = false)
    Colorize.enabled = colors
    content = if skip_reading_config
                "{}"
              else
                read_config(path) || "{}"
              end
    Config.new YAML.parse(content)
  rescue e
    raise "Unable to load config file: #{e.message}"
  end

  protected def self.read_config(path = nil)
    if path
      return File.read(path) if File.exists?(path)
      raise "Config file does not exist"
    end
    each_config_path do |config_path|
      return File.read(config_path) if File.exists?(config_path)
    end
  end

  protected def self.each_config_path(&)
    path = Path[DEFAULT_PATH].expand(home: true)

    search_paths = path.parents
    search_paths.reverse_each do |search_path|
      yield search_path / FILENAME
    end

    DEFAULT_PATHS.each do |default_path|
      yield default_path
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
  # config.globs = ["**/*.cr"]
  # config.excluded = ["spec"]
  # config.sources # => list of sources pointing to files found by the wildcards
  # ```
  def sources
    if file = stdin_filename
      [Source.new(STDIN.gets_to_end, file)]
    else
      (find_files_by_globs(globs) - find_files_by_globs(excluded))
        .map { |path| Source.new File.read(path), path }
    end
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
      .tap(&.excluded = excluded)
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
  def update_rules(names, enabled = true, excluded = nil)
    names.try &.each do |name|
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

  private def load_formatter_name(config)
    name = config["Formatter"]?.try &.["Name"]?
    name.try(&.to_s)
  end

  private def load_array_section(config, section_name, default = [] of String)
    case value = config[section_name]?
    when .nil?  then default
    when .as_s? then [value.to_s]
    when .as_a? then value.as_a.map(&.as_s)
    else
      raise "Incorrect '#{section_name}' section in a config files"
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
          {% if value.is_a? BoolLiteral %}
            {% type = Bool %}
          {% elsif value.is_a? StringLiteral %}
            {% type = String %}
          {% elsif value.is_a? NumberLiteral %}
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
        property excluded : Array(String)?
      {% end %}
    end

    macro included
      GROUP_SEVERITY = {
        Documentation: Ameba::Severity::Warning,
        Lint:          Ameba::Severity::Warning,
        Metrics:       Ameba::Severity::Warning,
        Performance:   Ameba::Severity::Warning,
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
