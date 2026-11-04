module Ameba
  # An entity that represents a Crystal source file.
  # Has path, lines of code and issues reported by rules.
  class Source
    include InlineComments
    include Reportable

    # Path to the source file.
    getter path : Path

    # Path to the source file relative to the project root.
    getter project_path : Path

    # Absolute path to the source file.
    getter fullpath : Path { path.expand }

    # Crystal code (content of a source file).
    getter code : String

    # Creates a new source by `code` and `path`.
    #
    # For example:
    #
    # ```
    # path = Path["src", "source.cr"]
    # Ameba::Source.new(File.read(path), path)
    # ```
    def initialize(@code = "", path : Path | String = "", project_path : Path | String = path)
      @path = Path[path]
      @project_path = Path[project_path]
    end

    # Corrects any correctable issues and updates `code`.
    # Returns the corrected issues, or `nil` if the code was unchanged.
    def correct! : Array(Issue)?
      corrected_code, corrected_issues = corrections(issues) { |_, ex| raise ex }
      return if code == corrected_code

      self.code = corrected_code

      corrected_issues
    end

    # Same as `#correct!`, but makes sure the source stays parsable. Corrections
    # breaking the syntax or raising an exception are dropped, which leaves their
    # issues reported as uncorrected.
    def correct_safely! : Array(Issue)?
      failures = [] of {Issue, Exception}

      corrected_code, corrected_issues = corrections(issues) do |issue, ex|
        failures << {issue, ex}
      end

      failures.each do |failed_issue, ex|
        reason = "correction raised an exception: #{ex.message} (#{ex.class})"
        drop_corrections(reason, crashed: true) { |issue| issue == failed_issue }
      end

      return if code == corrected_code
      return corrected_issues if adopt_parsable(corrected_code)

      # Retry without the corrections breaking the syntax on their own
      if breaking_issues = breaking_issues?(issues)
        drop_corrections { |issue| breaking_issues.includes?(issue) }
      end

      corrected_code, corrected_issues = corrections(issues) { }
      return if code == corrected_code
      return corrected_issues if adopt_parsable(corrected_code)

      # The remaining corrections break the syntax only when combined
      drop_corrections { true }

      nil
    end

    # Goes back to the given *code*, forgetting about the issues of the current one.
    def revert_to(code : String) : Nil
      self.code = code
      issues.clear
    end

    # Returns `true` if `code` has no syntax errors.
    def parsable? : Bool
      ast
      true
    rescue Crystal::SyntaxException
      false
    end

    # Replaces `code` and drops everything derived from it.
    private def code=(@code : String)
      @lines = nil
      @line_offsets = nil
      @ast = nil
    end

    # Returns the code with corrections of the given *candidates* applied, along
    # with the ones which got applied. Conflicting issues are deferred until
    # Runner reinspects the corrected source, as all corrections apply to the
    # same source snapshot. Yields the issues whose corrections raised an exception.
    private def corrections(candidates, &) : {String, Array(Issue)}
      corrector = Corrector.new(code, line_offsets)

      corrected_issues = candidates.select do |issue|
        issue.unresolved? &&
          corrector.transaction { issue.correct(corrector) }
      rescue ex
        yield issue, ex
        false
      end

      {corrector.process, corrected_issues}
    end

    # Replaces `code` with the given one, unless it has syntax errors.
    private def adopt_parsable(new_code) : Bool
      return false unless new_ast = parse?(new_code)

      self.code = new_code
      @ast = new_ast

      true
    end

    private def drop_corrections(reason = "would produce invalid syntax", *, crashed = false, &)
      issues.map! do |issue|
        next issue unless issue.correctable? && yield issue

        dropped_issue = issue.without_correction(
          "#{issue.message} (not corrected: #{reason})"
        )
        crashed ? dropped_issue.as_crashed : dropped_issue
      end
    end

    # Returns the *candidates* whose corrections break the syntax on their own.
    #
    # Bisects them, since parsing the outcome of each one separately would take
    # too long for a source with many issues.
    private def breaking_issues?(candidates) : Array(Issue)?
      return if candidates.empty?

      return if parse?(corrections(candidates) { }.first)
      return candidates if candidates.size == 1

      half = candidates.size // 2
      breaking_issues(candidates[0...half]) + breaking_issues(candidates[half..])
    end

    # :ditto:
    private def breaking_issues(candidates) : Array(Issue)
      breaking_issues?(candidates) || [] of Issue
    end

    # Returns lines of code split by new line character.
    # Since `code` is immutable and can't be changed, this
    # method caches lines in an instance variable, so calling
    # it a second time will not perform a split, but will return
    # lines instantly.
    #
    # ```
    # source = Ameba::Source.new("a = 1\nb = 2", path)
    # source.lines # => ["a = 1", "b = 2"]
    # ```
    getter lines : Array(String) { code.split(/\r?\n/) }

    # Positions at which the code lines start.
    private getter line_offsets : Array(Int32) { self.class.line_offsets(code) }

    # Returns positions at which lines of the given *code* start.
    def self.line_offsets(code : String) : Array(Int32)
      offsets = [0]
      code.each_char_with_index do |char, index|
        offsets << index + 1 if char == '\n'
      end
      offsets
    end

    # Returns AST nodes constructed by `Crystal::Parser`.
    #
    # ```
    # source = Ameba::Source.new(code, path)
    # source.ast
    # ```
    getter ast : Crystal::ASTNode { parse(code) }

    private def parse(code) : Crystal::ASTNode
      if ecr?
        begin
          code = ECR.process_string(code, path.to_s)
        rescue ex : ECR::Lexer::SyntaxException
          # Need to rescue to add the filename
          raise Crystal::SyntaxException.new(
            ex.message,
            ex.line_number,
            ex.column_number,
            path.to_s,
          )
        end
      end

      Crystal::Parser.new(code)
        .tap(&.wants_doc = true)
        .tap(&.filename = path.to_s)
        .parse
    end

    private def parse?(code) : Crystal::ASTNode?
      parse(code)
    rescue Crystal::SyntaxException
      nil
    end

    # Returns `true` if the source is a spec file, `false` otherwise.
    def spec?
      path.basename.ends_with?("_spec.cr")
    end

    # Returns `true` if the source is an ECR template, `false` otherwise.
    def ecr?
      path.basename.ends_with?(".ecr")
    end

    # Converts an AST location to a string position.
    def pos(location : Crystal::Location, end end_pos = false) : Int32
      line, column = location.line_number, location.column_number
      pos = line_offsets[line - 1] + column - 1
      pos += 1 if end_pos
      pos
    end
  end
end
