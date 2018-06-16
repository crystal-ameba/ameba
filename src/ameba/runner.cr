module Ameba
  # Represents a runner for inspecting sources files.
  # Holds a list of rules to do inspection based on,
  # list of sources to run inspection on and a formatter
  # to prepare a report.
  #
  # ```
  # config = Ameba::Config.load
  # runner = Ameba::Runner.new config
  # runner.run.success? # => true or false
  # ```
  #
  class Runner
    # A list of rules to do inspection based on.
    @rules : Array(Rule::Base)

    # A list of sources to run inspection on.
    getter sources : Array(Source)

    # A formatter to prepare report.
    @formatter : Formatter::BaseFormatter

    # A syntax rule which always inspects a source first
    @syntax_rule = Rule::Lint::Syntax.new

    # Checks for unneeded disable directives. Always inspects a source last
    @unneeded_disable_directive_rule : Rule::Base?

    # Instantiates a runner using a `config`.
    #
    # ```
    # config = Ameba::Config.load
    # config.files = files
    # config.formatter = formatter
    #
    # Ameba::Runner.new config
    # ```
    #
    def initialize(config : Config)
      @sources = load_sources(config)
      @formatter = config.formatter
      @rules = config.rules.select(&.enabled).reject!(&.special?)

      @unneeded_disable_directive_rule =
        config.rules
              .find &.name.==(Rule::Lint::UnneededDisableDirective.rule_name)
    end

    # :nodoc:
    protected def initialize(@rules, @sources, @formatter)
    end

    # Performs the inspection. Iterates through all sources and test it using
    # list of rules. If a specific rule fails on a specific source, it adds
    # an issue to that source.
    #
    # This action also notifies formatter when inspection is started/finished,
    # and when a specific source started/finished to be inspected.
    #
    # ```
    # runner = Ameba::Runner.new config
    # runner.run # => returns runner again
    # ```
    #
    def run
      @formatter.started @sources
      @sources.each do |source|
        @formatter.source_started source

        if @syntax_rule.catch(source).valid?
          @rules.each do |rule|
            next if rule.excluded?(source)
            rule.test(source)
          end
          check_unneeded_directives(source)
        end

        @formatter.source_finished source
      end
      self
    ensure
      @formatter.finished @sources
    end

    # Indicates whether the last inspection successful or not.
    # It returns true if no issues in sources found, false otherwise.
    #
    # ```
    # runner = Ameba::Runner.new config
    # runner.run
    # runner.success? # => true or false
    # ```
    #
    def success?
      @sources.all? &.valid?
    end

    private def check_unneeded_directives(source)
      if (rule = @unneeded_disable_directive_rule) && rule.enabled
        rule.test(source)
      end
    end

    private def load_sources(config)
      config.files.map do |wildcard|
        wildcard += "/**/*.cr" if File.directory?(wildcard)
        Dir[wildcard]
      end.flatten
         .map { |path| Source.new File.read(path), path }
    end
  end
end
