class Ameba::Source
  # Applies the corrections of the issues of a source.
  class Correction
    def initialize(@source : Source)
    end

    # Applies the corrections, passing on any exception they raise.
    # Returns the corrected issues, or `nil` if the code was unchanged.
    def apply : Array(Issue)?
      corrected_code, corrected_indexes =
        corrections(all_indexes) { |_, ex| raise ex }

      return if @source.code == corrected_code
      @source.replace_code(corrected_code)

      corrected_indexes.map { |index| issues[index] }
    end

    # Same as `#apply`, but makes sure the source stays parsable. Corrections
    # breaking the syntax or raising an exception are dropped, which leaves their
    # issues reported as uncorrected.
    def apply_safely : Array(Issue)?
      loop do
        corrected_code, corrected_indexes = attempt_corrections
        return if @source.code == corrected_code

        if new_ast = @source.parse?(corrected_code)
          @source.replace_code(corrected_code, new_ast)
          return corrected_indexes.map { |index| issues[index] }
        end

        # Retry without the corrections breaking the syntax on their own, or
        # else without all of the applied ones, which break it only when combined.
        # The deferred ones get their turn, as each retry drops at least one.
        breaking_indexes = breaking_indexes(corrected_indexes)
        breaking_indexes = corrected_indexes if breaking_indexes.empty?
        breaking_indexes = breaking_indexes.to_set

        drop_corrections do |index|
          "would produce invalid syntax" if index.in?(breaking_indexes)
        end
      end
    end

    # The issues are tracked by their indexes, which stay the same as
    # `#drop_corrections` replaces them in place. Hashing an issue would
    # hash the code of the whole source along with it.
    private def issues
      @source.issues
    end

    private def all_indexes
      Array.new(issues.size, &.itself)
    end

    # Returns the code with corrections of the issues at the given *candidates*
    # indexes applied, along with the indexes of the ones which got applied.
    # Conflicting issues are deferred until Runner reinspects the corrected source,
    # as all corrections apply to the same source snapshot. Yields the indexes of
    # the issues whose corrections raised an exception.
    private def corrections(candidates, &) : {String, Array(Int32)}
      corrector = Corrector.new(@source.code, @source.line_offsets)

      corrected_indexes = candidates.select do |index|
        issue = issues[index]
        issue.unresolved? &&
          corrector.transaction { issue.correct(corrector) }
      rescue ex
        yield index, ex
        false
      end

      {corrector.process, corrected_indexes}
    end

    # Same as `#corrections` of all the issues, but drops the corrections
    # which raise an exception.
    private def attempt_corrections : {String, Array(Int32)}
      failures = {} of Int32 => Exception

      result = corrections(all_indexes) do |index, ex|
        failures[index] = ex
      end

      unless failures.empty?
        drop_corrections(outcome: :crashed) do |index|
          next unless ex = failures[index]?
          "correction raised an exception: #{ex.message} (#{ex.class})"
        end
      end

      result
    end

    # Drops the corrections of the issues for whose indexes the block returns
    # the reason for doing so.
    private def drop_corrections(*, outcome : Issue::Outcome = :pending, & : Int32 -> String?)
      issues.map_with_index! do |issue, index|
        next issue unless issue.correctable?
        next issue unless reason = yield index

        issue.without_correction(
          "#{issue.message} (not corrected: #{reason})",
          outcome: outcome,
        )
      end
    end

    # Returns the *candidates* indexes of the issues whose corrections break
    # the syntax on their own, given that combined they do break it.
    #
    # Bisects them, since parsing the outcome of each one separately would take
    # too long for a source with many issues.
    private def breaking_indexes(candidates) : Array(Int32)
      return candidates if candidates.size == 1

      half = candidates.size // 2

      {candidates[0...half], candidates[half..]}.flat_map do |part|
        next [] of Int32 if @source.parse?(corrections(part) { }.first)
        breaking_indexes(part)
      end
    end
  end
end
