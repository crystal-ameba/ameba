require "yaml"

# A configuration entry for `Ameba::Runner`.
#
# Config can be loaded from configuration YAML file and adjusted.
#
# ```
# config = Config.load
# config.formatter = my_formatter
# ```
#
# By default config loads `.ameba.yml` file in a current directory.
#
class Ameba::Config
  setter formatter : Formatter::BaseFormatter?
  setter files : Array(String)?

  # Creates a new instance of `Ameba::Config` based on YAML parameters.
  #
  # `Config.load` uses this constructor to instantiate new config by YAML file.
  protected def initialize(@config : YAML::Any)
  end

  # Loads YAML configuration file by `path`.
  #
  # ```
  # config = Ameba::Config.load
  # ```
  #
  def self.load(path = nil)
    path ||= ".ameba.yml"
    content = File.exists?(path) ? File.read path : "{}"
    Config.new YAML.parse(content)
  end

  # Returns a list of paths (with wildcards) to files.
  # Represents a list of sources to be inspected.
  # If files are not set, it will return default list of files.
  #
  # ```
  # config = Ameba::Config.load
  # config.files = ["**/*.cr"]
  # config.files
  # ```
  #
  def files
    @files ||= default_files
  end

  # Returns a formatter to be used while inspecting files.
  # If formatter is not set, it will return default formatter.
  #
  # ```
  # config = Ameba::Config.load
  # config.formatter = custom_formatter
  # config.formatter
  # ```
  #
  def formatter
    @formatter ||= default_formatter
  end

  # Returns a subconfig of a fully loaded configuration.
  # This is used to get a config for a specific rule.
  #
  # ```
  # config = Ameba::Config.load
  # config.subconfig "LineLength"
  # ```
  #
  def subconfig(name)
    @config[name]?
  end

  private def default_files
    Dir["**/*.cr"].reject(&.starts_with? "lib/")
  end

  private def default_formatter
    Formatter::DotFormatter.new
  end

  # :no_doc:
  module Rule
    macro properties(&block)
      {% definitions = [] of NamedTuple %}
      {% if block.body.is_a? Assign %}
        {% definitions << {var: block.body.target, value: block.body.value} %}
      {% elsif block.body.is_a? TypeDeclaration %}
        {% definitions << {var: block.body.var, value: block.body.value, type: block.body.type} %}
      {% elsif block.body.is_a? Expressions %}
        {% for prop in block.body.expressions %}
          {% if prop.is_a? Assign %}
            {% definitions << {var: prop.target, value: prop.value} %}
          {% elsif prop.is_a? TypeDeclaration %}
            {% definitions << {var: prop.var, value: prop.value, type: prop.type} %}
          {% end %}
        {% end %}
      {% end %}

      {% properties = {} of MacroId => NamedTuple %}
      {% for df in definitions %}
        {% name = df[:var].id %}
        {% key = name.camelcase.stringify %}
        {% value = df[:value] %}
        {% type = df[:type] %}

        {% if type == nil %}
          {% if value.is_a? BoolLiteral %}
            {% type = Bool %}
          {% elsif value.is_a? StringLiteral %}
            {% type = String %}
          {% elsif value.is_a? NumberLiteral %}
            {% if value.kind == :i32 %}
              {% type = Int32 %}
            {% elsif value.kind == :i64 %}
              {% type = Int64 %}
            {% elsif value.kind == :f32 %}
              {% type = Float32 %}
            {% elsif value.kind == :f64 %}
              {% type = Float64 %}
            {% end %}
          {% end %}

          {% type = Nil if type == nil %}
        {% end %}

        {% properties[name] = {key: key, default: value, type: type} %}
      {% end %}

      {% if properties["enabled".id] == nil %}
        {% properties["enabled".id] = {key: "Enabled", default: true, type: Bool} %}
      {% end %}

      YAML.mapping({{properties}})
    end

    macro included
      macro inherited
        # allow creating rules without properties
        properties {}

        def self.new(config : Ameba::Config? = nil)
          yaml = config.try &.subconfig(class_name).try &.to_yaml || "{}"
          from_yaml yaml
        end
      end
    end
  end
end
