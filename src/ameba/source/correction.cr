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
      adopt_corrections do
        # Retry without the corrections breaking the syntax on their own
        breaking_issues = breaking_issues(issues)
        drop_corrections(&.in?(breaking_issues))

        adopt_corrections do
          # The remaining corrections break the syntax only when combined
          drop_corrections { true }

          nil
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

    # Replaces the code with the corrected one, dropping the corrections which raise.
    # Returns the corrected issues, `nil` if the code was unchanged, or the result
    # of the block if the corrected code has syntax errors.
    private def adopt_corrections(&) : Array(Issue)?
      failures = [] of {Issue, Exception}

      corrected_code, corrected_issues = corrections(issues) do |issue, ex|
        failures << {issue, ex}
      end

      failures.each do |failed_issue, ex|
        reason = "correction raised an exception: #{ex.message} (#{ex.class})"
        drop_corrections(reason, outcome: :crashed) { |issue| issue == failed_issue }
      end

      return if @source.code == corrected_code

      if new_ast = @source.parse?(corrected_code)
        @source.replace_code(corrected_code, new_ast)

        return corrected_issues
      end

      yield
    end

    private def drop_corrections(reason = "would produce invalid syntax", *, outcome : Issue::Outcome = :pending, &)
      issues.map! do |issue|
        next issue unless issue.correctable? && yield issue

        issue.without_correction(
          "#{issue.message} (not corrected: #{reason})",
          outcome: outcome,
        )
      end
    end

    # Returns the *candidates* whose corrections break the syntax on their own.
    #
    # Bisects them, since parsing the outcome of each one separately would take
    # too long for a source with many issues.
    private def breaking_issues(candidates) : Array(Issue)
      return [] of Issue if @source.parse?(corrections(candidates) { }.first)
      return candidates if candidates.size == 1

      half = candidates.size // 2
      breaking_issues(candidates[0...half]) + breaking_issues(candidates[half..])
    end
  end
end
