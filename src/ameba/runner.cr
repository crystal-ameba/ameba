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
    @sources : Array(Source)

    # A formatter to prepare report.
    @formatter : Formatter::BaseFormatter

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
      @rules = load_rules(config)
      @sources = load_sources(config)
      @formatter = config.formatter
    end

    # Instantiates a runner using a list of sources and a formatter.
    #
    # ```
    # runner = Ameba::Runner.new sources, formatter
    # ```
    #
    def initialize(@sources, @formatter)
      @rules = load_rules nil
    end

    # Performs the inspection. Iterates through all sources and test it using
    # list of rules. If a specific rule fails on a specific source, it adds
    # an error to that source.
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

        @rules.each &.test(source)

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

    private def load_sources(config)
      config.files
            .map { |wildcard| Dir[wildcard] }
            .flatten
            .map { |path| Source.new File.read(path), path }
    end

    private def load_rules(config)
      Rule.rules.map { |r| r.new config }.select &.enabled?
    end
  end
end
