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
  class Runner
    # An error indicating that the inspection loop got stuck correcting
    # issues back and forth.
    class InfiniteCorrectionLoopError < RuntimeError
      def initialize(path, issues_by_iteration, loop_start = -1)
        root_cause =
          issues_by_iteration[loop_start..-1]
            .join(" -> ", &.map(&.rule.name).uniq!.join(", "))

        message = String.build do |io|
          io << "Infinite loop"
          io << " in " << path unless path.empty?
          io << " caused by " << root_cause
        end

        super message
      end
    end

    # A list of rules to do inspection based on.
    @rules : Array(Rule::Base)

    # A list of sources to run inspection on.
    getter sources : Array(Source)

    # A level of severity to be reported.
    @severity : Severity

    # A formatter to prepare report.
    @formatter : Formatter::BaseFormatter

    # A syntax rule which always inspects a source first
    @syntax_rule = Rule::Lint::Syntax.new

    # Checks for unneeded disable directives. Always inspects a source last
    @unneeded_disable_directive_rule : Rule::Base?

    # Returns `true` if correctable issues should be autocorrected.
    private getter? autocorrect : Bool

    # Instantiates a runner using a `config`.
    #
    # ```
    # config = Ameba::Config.load
    # config.files = files
    # config.formatter = formatter
    #
    # Ameba::Runner.new config
    # ```
    def initialize(config : Config)
      @sources = config.sources
      @formatter = config.formatter
      @severity = config.severity
      @rules = config.rules.select(&.enabled?).reject!(&.special?)
      @autocorrect = config.autocorrect?

      @unneeded_disable_directive_rule =
        config.rules
          .find &.class.==(Rule::Lint::UnneededDisableDirective)
    end

    protected def initialize(@rules, @sources, @formatter, @severity, @autocorrect = false)
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
    def run
      @formatter.started @sources

      channels = @sources.map { Channel(Exception?).new }
      @sources.zip(channels).each do |source, channel|
        spawn do
          run_source(source)
        rescue e
          channel.send(e)
        else
          channel.send(nil)
        end
      end

      channels.each do |chan|
        chan.receive.try { |e| raise e }
      end

      self
    ensure
      @formatter.finished @sources
    end

    private def run_source(source) : Nil
      @formatter.source_started source

      # This variable is a 2D array used to track corrected issues after each
      # inspection iteration. This is used to output meaningful infinite loop
      # error message.
      corrected_issues = [] of Array(Issue)

      # When running with --fix, we need to inspect the source until no more
      # corrections are made (because automatic corrections can introduce new
      # issues). In the normal case the loop is only executed once.
      loop_unless_infinite(source, corrected_issues) do
        # We have to reprocess the source to pick up any changes. Since a
        # change could (theoretically) introduce syntax errors, we break the
        # loop if we find any.
        @syntax_rule.test(source)
        break unless source.valid?

        @rules.each do |rule|
          next if rule.excluded?(source)
          rule.test(source)
        end
        check_unneeded_directives(source)
        break unless autocorrect? && source.correct?

        # The issues that couldn't be corrected will be found again so we
        # only keep the corrected ones in order to avoid duplicate reporting.
        corrected_issues << source.issues.select(&.correctable?)
        source.issues.clear
      end

      corrected_issues.flatten.reverse_each do |issue|
        source.issues.unshift(issue)
      end

      File.write(source.path, source.code) unless corrected_issues.empty?
    ensure
      @formatter.source_finished source
    end

    # Explains an issue at a specified *location*.
    #
    # Runner should perform inspection before doing the explain.
    # This is necessary to be able to find the issue at a specified location.
    #
    # ```
    # runner = Ameba::Runner.new config
    # runner.run
    # runner.explain({file: file, line: l, column: c})
    # ```
    def explain(location, output = STDOUT)
      Formatter::ExplainFormatter.new(output, location).finished @sources
    end

    # Indicates whether the last inspection successful or not.
    # It returns `true` if no issues matching severity in sources found, `false` otherwise.
    #
    # ```
    # runner = Ameba::Runner.new config
    # runner.run
    # runner.success? # => true or false
    # ```
    def success?
      @sources.all? &.issues.none? do |issue|
        issue.enabled? && issue.rule.severity <= @severity
      end
    end

    private MAX_ITERATIONS = 200

    private def loop_unless_infinite(source, corrected_issues, &)
      # Keep track of the state of the source. If a rule modifies the source
      # and another rule undoes it producing identical source we have an
      # infinite loop.
      processed_sources = [] of UInt64

      # It is possible for a rule to keep adding indefinitely to a file,
      # making it bigger and bigger. If the inspection loop runs for an
      # excessively high number of iterations, this is likely happening.
      iterations = 0

      loop do
        check_for_infinite_loop(source, corrected_issues, processed_sources)

        if (iterations += 1) > MAX_ITERATIONS
          raise InfiniteCorrectionLoopError.new(source.path, corrected_issues)
        end

        yield
      end
    end

    # Check whether a run created source identical to a previous run, which
    # means that we definitely have an infinite loop.
    private def check_for_infinite_loop(source, corrected_issues, processed_sources)
      checksum = source.code.hash

      if loop_start = processed_sources.index(checksum)
        raise InfiniteCorrectionLoopError.new(
          source.path,
          corrected_issues,
          loop_start: loop_start
        )
      end

      processed_sources << checksum
    end

    private def check_unneeded_directives(source)
      return unless rule = @unneeded_disable_directive_rule
      return unless rule.enabled?

      rule.test(source)
    end
  end
end
