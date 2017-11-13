require "yaml"

class Ameba::Config
  setter formatter : Formatter::BaseFormatter?
  setter files : Array(String)?

  def initialize(@config : YAML::Any)
  end

  def self.load(path = ".ameba.yml")
    content = (path && File.exists? path) ? File.read path : "{}"
    Config.new YAML.parse(content)
  end

  def files
    @files ||= default_files
  end

  def formatter
    @formatter ||= default_formatter
  end

  def subconfig(name)
    @config[name]?
  end

  private def default_files
    Dir["**/*.cr"].reject(&.starts_with? "lib/")
  end

  private def default_formatter
    Formatter::DotFormatter.new
  end

  module Rule
    getter config : YAML::Any?

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
