module Ameba
  # Represents a runner for inspecting source files.
  # Holds a list of rules to do inspection based on,
  # list of sources to run inspection on and a formatter
  # to prepare a report.
  #
  # ```
  # config = Ameba::Config.load
  # runner = Ameba::Runner.new(config)
  # runner.run.success? # => true or false
  # ```
  class Runner
    # A list of rules to do inspection based on.
    @rules : Array(Rule::Base)

    # Project root path.
    getter root : Path

    # A list of sources to run inspection on.
    getter sources : Array(Source)

    # A level of severity to be reported.
    @severity : Severity

    # A formatter to prepare report.
    @formatter : Formatter::BaseFormatter

    # A syntax rule which always inspects a source first
    @syntax_rule = Rule::Lint::Syntax.new

    # Checks for unneeded disable directives. Always inspects a source last
    @unneeded_disable_directive_rule : Rule::Lint::UnneededDisableDirective?

    # Returns `true` if correctable issues should be autocorrected.
    private getter? autocorrect : Bool

    # Returns an ameba version up to which the rules should be run.
    property version : SemanticVersion?

    # Instantiates a runner using a `config`.
    #
    # ```
    # config = Ameba::Config.load
    # config.files = files
    # config.formatter = formatter
    #
    # runner = Ameba::Runner.new(config)
    # ```
    def initialize(config : Config)
      initialize(
        config.rules,
        config.sources,
        config.formatter,
        config.severity,
        config.autocorrect?,
        config.version,
        config.root,
      )
    end

    protected def initialize(rules, sources, @formatter, @severity, @autocorrect = false, @version = nil, @root = Path[Dir.current])
      @sources = sources.sort_by(&.path)
      @rules =
        rules.select(&->rule_runnable?(Rule::Base))
      @unneeded_disable_directive_rule =
        rules.find(&.class.==(Rule::Lint::UnneededDisableDirective))
          .as?(Rule::Lint::UnneededDisableDirective)
    end

    protected def rule_runnable?(rule)
      rule.enabled? && !rule.special? &&
        rule_satisfies_severity?(rule, @severity) &&
        rule_satisfies_version?(rule, @version)
    end

    protected def rule_satisfies_severity?(rule, severity)
      rule.severity <= severity
    end

    protected def rule_satisfies_version?(rule, version)
      !version || !(since_version = rule.since_version) ||
        since_version <= version
    end

    # Performs the inspection. Iterates through all sources and tests them using
    # list of rules. If a specific rule fails on a specific source, it adds
    # an issue to that source.
    #
    # This action also notifies formatter when inspection is started/finished,
    # and when a specific source started/finished to be inspected.
    #
    # ```
    # runner = Ameba::Runner.new(config)
    # runner.run # => returns runner again
    # ```
    def run
      @formatter.started(@sources)

      channels = @sources.map { Channel(Exception?).new }
      @sources.zip(channels).each do |source, channel|
        spawn do
          run_source(source)
        rescue ex
          channel.send(ex)
        else
          channel.send(nil)
        end
      end

      # Let the other sources finish first, as they might get corrected on disk
      channels.compact_map(&.receive).first?.try { |ex| raise ex }

      self
    ensure
      @formatter.finished(@sources)
    end

    private def run_source(source) : Nil
      @formatter.source_started(source)

      # This variable is a 2D array used to track corrected issues after each
      # inspection iteration. This is used to output meaningful infinite loop
      # error message.
      corrected_issues = [] of Array(Issue)
      original_code = source.code

      # When running with --fix, we need to inspect the source until no more
      # corrections are made (because automatic corrections can introduce new
      # issues). In the normal case the loop is only executed once.
      loop_message = loop_unless_infinite(source, corrected_issues) do
        break unless inspect_source(source)
        break unless autocorrect?

        applied_issues = source.correct_safely!
        break unless applied_issues

        # The issues that couldn't be corrected will be found again so we
        # only keep the corrected ones in order to avoid duplicate reporting.
        corrected_issues << applied_issues.map(&.as_corrected)
        source.issues.clear
      end

      if loop_message
        return report_failure(source, original_code, corrected_issues, loop_message)
      end

      begin
        File.write(source.path, source.code) unless corrected_issues.empty?
      rescue ex
        message = "Could not write the corrected code: #{ex.message}"
        return report_failure(source, original_code, corrected_issues, message)
      end

      source.issues[0, 0] = corrected_issues.flatten
    ensure
      source.issues.sort_by! do |issue|
        {
          issue.location.try(&.line_number) || 0,
          issue.location.try(&.column_number) || 0,
        }
      end
      @formatter.source_finished(source)
    end

    # Explains an issue at a specified *location*.
    #
    # Runner should perform inspection before doing the explain.
    # This is necessary to be able to find the issue at a specified location.
    #
    # ```
    # runner = Ameba::Runner.new(config)
    # runner.run
    # runner.explain(Crystal::Location.new(file, line, column))
    # ```
    def explain(location, output = STDOUT)
      Formatter::ExplainFormatter.new(output, location).finished(@sources)
    end

    # Indicates whether the last inspection successful or not.
    # It returns `true` if no issues are left, `false` otherwise.
    #
    # ```
    # runner = Ameba::Runner.new(config)
    # runner.run
    # runner.success? # => true or false
    # ```
    def success?
      @sources.all?(&.valid?)
    end

    # Indicates whether any rule or correction raised an exception,
    # or corrections got stuck in a loop during the last inspection.
    #
    # ```
    # runner = Ameba::Runner.new(config)
    # runner.run
    # runner.crashed? # => true or false
    # ```
    def crashed?
      @sources.any?(&.issues.any?(&.crashed?))
    end

    private MAX_ITERATIONS = 200

    # Runs the block until it breaks out, which returns `nil`, or until
    # it gets stuck, which returns a message describing what caused that.
    private def loop_unless_infinite(source, corrected_issues, &) : String?
      # Keep track of the state of the source. If a rule modifies the source
      # and another rule undoes it producing identical source we have an
      # infinite loop.
      processed_sources = [] of UInt64

      # It is possible for a rule to keep adding indefinitely to a file,
      # making it bigger and bigger. If the inspection loop runs for an
      # excessively high number of iterations, this is likely happening.
      iterations = 0

      loop do
        checksum = source.code.hash

        if loop_start = processed_sources.index(checksum)
          return infinite_loop_message(source, corrected_issues[loop_start..])
        end
        processed_sources << checksum

        if (iterations += 1) > MAX_ITERATIONS
          return infinite_loop_message(source, corrected_issues.last(1))
        end

        yield
      end
    end

    private def infinite_loop_message(source, issues_by_iteration)
      root_cause =
        issues_by_iteration.join(" -> ", &.map(&.rule.name).uniq!.join(", "))

      "Infinite loop in #{source.path} caused by #{root_cause}"
    end

    # Inspects the source, returning `false` if it has syntax errors,
    # in which case there's nothing to inspect or correct.
    private def inspect_source(source) : Bool
      @syntax_rule.test(source)
      return false unless source.valid?

      excluded_rules = Set(String).new

      @rules.each do |rule|
        if rule.excluded?(source, root)
          excluded_rules << rule.name
          next
        end
        # Whether its directives are needed is unknown if the rule hasn't finished
        if report_exception(source, rule) { rule.test(source) }
          excluded_rules << rule.name
        end
      end

      check_unneeded_directives(source, excluded_rules)

      true
    end

    # Goes back to the original code, so that nothing gets reported as corrected,
    # and reports the failure along with the issues of that code.
    private def report_failure(source, original_code, corrected_issues, message) : Nil
      source.revert_to(original_code)
      inspect_source(source)

      source.add_crash_issue(corrected_issues.last.first.rule, message)
    end

    private def check_unneeded_directives(source, excluded_rules = Set(String).new)
      return unless rule = @unneeded_disable_directive_rule
      return unless rule.enabled?
      return if rule.excluded?(source, root)

      report_exception(source, rule) { rule.test(source, excluded_rules) }
    end

    # Reports an exception raised by a *rule* as an issue, so that it fails the
    # run without stopping the other rules and sources from being inspected.
    # Returns `true` if that happened.
    private def report_exception(source, rule, &) : Bool
      yield
      false
    rescue ex
      message = "Rule raised an exception: #{ex.message} (#{ex.class})"

      source.add_crash_issue(rule, message)
      true
    end
  end
end
