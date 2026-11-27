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

    # Creates a new source from the file at the given *path*. If it can't
    # be read, the source has no code and reports that as an issue.
    def self.from_file(path : Path | String, project_path : Path | String = path) : self
      new(File.read(path), path, project_path)
    rescue ex : IO::Error
      new(path: path, project_path: project_path).tap do |source|
        source.add_crash_issue Rule::Lint::Syntax.new,
          "Could not read the file: #{ex.message}"
      end
    end

    # Corrects any correctable issues and updates `code`.
    # Returns the corrected issues, or `nil` if the code was unchanged.
    def correct! : Array(Issue)?
      Correction.new(self).apply
    end

    # Same as `#correct!`, but makes sure the source stays parsable. Corrections
    # breaking the syntax or raising an exception are dropped, which leaves their
    # issues reported as uncorrected.
    def correct_safely! : Array(Issue)?
      Correction.new(self).apply_safely
    end

    # Goes back to the given *code*, forgetting about the issues of the current one.
    def revert_to(code : String) : Nil
      replace_code(code)
      issues.clear
    end

    # Returns `true` if `code` has no syntax errors, nor invalid UTF-8.
    def parsable? : Bool
      ast
      true
    rescue Crystal::SyntaxException | InvalidByteSequenceError
      false
    end

    # Replaces `code` and drops everything derived from it,
    # unless it comes with the *ast* already parsed from that code.
    protected def replace_code(@code, @ast = nil) : Nil
      @lines = nil
      @line_offsets = nil
    end

    # Returns lines of code split by new line character.
    # This method caches lines in an instance variable until
    # `code` changes, so calling it a second time will not
    # perform a split, but will return lines instantly.
    #
    # ```
    # source = Ameba::Source.new("a = 1\nb = 2", path)
    # source.lines # => ["a = 1", "b = 2"]
    # ```
    getter lines : Array(String) { code.split(/\r?\n/) }

    # Positions at which the code lines start.
    protected getter line_offsets : Array(Int32) { self.class.line_offsets(code) }

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

    protected def parse?(code) : Crystal::ASTNode?
      parse(code)
    rescue Crystal::SyntaxException | InvalidByteSequenceError
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
