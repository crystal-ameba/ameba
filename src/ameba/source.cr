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
      corrector = Corrector.new(code)

      # Corrections all apply to the same source snapshot. Conflicting issues
      # are deferred until Runner reinspects the corrected source.
      corrected_issues = issues.select do |issue|
        issue.enabled? && issue.correctable? &&
          corrector.transaction { issue.correct(corrector) }
      end

      corrected_code = corrector.process
      return if code == corrected_code

      self.code = corrected_code

      corrected_issues
    end

    # Same as `#correct!`, but makes sure the source stays parsable. Corrections
    # breaking the syntax are dropped, which leaves their issues reported as
    # uncorrected.
    def correct_safely! : Array(Issue)?
      previous_code = code

      corrected_issues = correct!
      return corrected_issues if !corrected_issues || parsable?

      # Retry without the corrections breaking the syntax on their own
      self.code = previous_code
      drop_corrections { |issue| !correction_parsable?(issue) }

      corrected_issues = correct!
      return corrected_issues if !corrected_issues || parsable?

      # The remaining corrections break the syntax only when combined
      self.code = previous_code
      drop_corrections { true }

      nil
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

    private def drop_corrections(&)
      issues.map! do |issue|
        next issue unless issue.correctable? && yield issue

        issue.without_correction("#{issue.message} (not corrected: would produce invalid syntax)")
      end
    end

    # Returns `true` if correcting only the given *issue* keeps the source parsable.
    private def correction_parsable?(issue)
      probe = self.class.new(code, path)
      probe.issues << issue

      !probe.correct! || probe.parsable?
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
    private getter line_offsets : Array(Int32) do
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
    getter ast : Crystal::ASTNode do
      code = @code

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
