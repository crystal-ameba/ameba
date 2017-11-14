module Ameba
  class Runner
    @rules : Array(Rule::Base)
    @sources : Array(Source)
    @formatter : Formatter::BaseFormatter

    def initialize(config : Config)
      @rules = load_rules(config)
      @sources = load_sources(config)
      @formatter = config.formatter
    end

    def initialize(@sources, @formatter)
      @rules = load_rules nil
    end

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
