class Ameba::Source
  # Applies the corrections of the issues of a source.
  class Correction
    def initialize(@source : Source)
    end

    # Applies the corrections, passing on any exception they raise.
    # Returns the corrected issues, or `nil` if the code was unchanged.
    def apply : Array(Issue)?
      corrected_code, corrected_issues =
        corrections(issues) { |_, ex| raise ex }

      return if @source.code == corrected_code
      @source.replace_code(corrected_code)

      corrected_issues
    end

    # Same as `#apply`, but makes sure the source stays parsable. Corrections
    # breaking the syntax or raising an exception are dropped, which leaves their
    # issues reported as uncorrected.
    def apply_safely : Array(Issue)?
      loop do
        corrected_code, corrected_issues = attempt_corrections
        return if @source.code == corrected_code

        if new_ast = @source.parse?(corrected_code)
          @source.replace_code(corrected_code, new_ast)
          return corrected_issues
        end

        # Retry without the corrections breaking the syntax on their own, or
        # else without all of the applied ones, which break it only when combined.
        # The deferred ones get their turn, as each retry drops at least one.
        breaking_issues = breaking_issues(corrected_issues)
        breaking_issues = corrected_issues if breaking_issues.empty?
        breaking_issues = breaking_issues.to_set

        drop_corrections do |issue|
          "would produce invalid syntax" if issue.in?(breaking_issues)
        end
      end
    end

    private def issues
      @source.issues
    end

    # Returns the code with corrections of the given *candidates* applied, along
    # with the ones which got applied. Conflicting issues are deferred until
    # Runner reinspects the corrected source, as all corrections apply to the
    # same source snapshot. Yields the issues whose corrections raised an exception.
    private def corrections(candidates, &) : {String, Array(Issue)}
      corrector = Corrector.new(@source.code, @source.line_offsets)

      corrected_issues = candidates.select do |issue|
        issue.unresolved? &&
          corrector.transaction { issue.correct(corrector) }
      rescue ex
        yield issue, ex
        false
      end

      {corrector.process, corrected_issues}
    end

    # Same as `#corrections` of all the issues, but drops the corrections
    # which raise an exception.
    private def attempt_corrections : {String, Array(Issue)}
      failures = {} of Issue => Exception

      result = corrections(issues) do |issue, ex|
        failures[issue] = ex
      end

      unless failures.empty?
        drop_corrections(outcome: :crashed) do |issue|
          next unless ex = failures[issue]?
          "correction raised an exception: #{ex.message} (#{ex.class})"
        end
      end

      result
    end

    # Drops the corrections of the issues for which the block returns
    # the reason for doing so.
    private def drop_corrections(*, outcome : Issue::Outcome = :pending, & : Issue -> String?)
      issues.map! do |issue|
        next issue unless issue.correctable?
        next issue unless reason = yield issue

        issue.without_correction(
          "#{issue.message} (not corrected: #{reason})",
          outcome: outcome,
        )
      end
    end

    # Returns the *candidates* whose corrections break the syntax on their own,
    # given that combined they do break it.
    #
    # Bisects them, since parsing the outcome of each one separately would take
    # too long for a source with many issues.
    private def breaking_issues(candidates) : Array(Issue)
      return candidates if candidates.size == 1

      half = candidates.size // 2

      {candidates[0...half], candidates[half..]}.flat_map do |part|
        next [] of Issue if @source.parse?(corrections(part) { }.first)
        breaking_issues(part)
      end
    end
  end
end
