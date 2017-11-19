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

  # An entity that represents a corresponding configuration for a specific Rule.
  module Rule
    # Represents a configuration of a specific Rule.
    getter config : YAML::Any?

    # A macro that defines a dsl to define configurable properties.
    #
    # ```
    # class Configurable
    #   include Ameba::Config::Rule
    #
    #   prop enabled? = false
    #   prop max_length = 80
    #   prop wildcard = "*"
    # end
    # ```
    #
    macro prop(assign)
      # Rule configuration property.
      def {{assign.target}}
        {% prop_name = assign.target.id.camelcase.gsub(/\?/, "") %}

        {% if assign.value.is_a? NumberLiteral %}
          int_prop "{{prop_name}}", {{assign.value}}
        {% elsif assign.value.is_a? BoolLiteral %}
          bool_prop "{{prop_name}}", {{assign.value}}
        {% elsif assign.value.is_a? StringLiteral %}
          str_prop "{{prop_name}}", {{assign.value}}
        {% end %}
      end
    end

    # Creates an instance of a Rule configuration.
    #
    # ```
    # class Configurable
    #   include Ameba::Config::Rule
    #
    #   prop enabled? = false
    #   prop max_length = 80
    #   prop wildcard = "*"
    # end
    #
    # Configurable.new config
    # ```
    #
    def initialize(config = nil)
      @config = config.try &.subconfig(name)
    end

    protected def int_prop(name, default : Number)
      str_prop(name, default).to_i
    end

    protected def bool_prop(name, default : Bool)
      str_prop(name, default.to_s) == "true"
    end

    protected def str_prop(name, default)
      config.try &.[name]?.try &.as_s || default
    end
  end
end
