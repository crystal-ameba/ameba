module Ameba
  # An entity that represents a Crystal source file.
  # Has path, lines of code and issues reported by rules.
  class Source
    include InlineComments
    include Reportable

    # Path to the source file.
    getter path : String

    # Crystal code (content of a source file).
    getter code : String

    # Creates a new source by `code` and `path`.
    #
    # For example:
    #
    # ```
    # path = "./src/source.cr"
    # Ameba::Source.new File.read(path), path
    # ```
    def initialize(@code, @path = "")
    end

    # Returns lines of code splitted by new line character.
    # Since `code` is immutable and can't be changed, this
    # method caches lines in an instance variable, so calling
    # it second time will not perform a split, but will return
    # lines instantly.
    #
    # ```
    # source = Ameba::Source.new "a = 1\nb = 2", path
    # source.lines # => ["a = 1", "b = 2"]
    # ```
    #
    getter lines : Array(String) { code.split('\n') }

    # Returns AST nodes constructed by `Crystal::Parser`.
    #
    # ```
    # source = Ameba::Source.new code, path
    # source.ast
    # ```
    #
    getter ast : Crystal::ASTNode do
      Crystal::Parser.new(code)
        .tap(&.wants_doc = true)
        .tap(&.filename = path)
        .parse
    end

    getter fullpath : String do
      File.expand_path(path)
    end

    # Returns `true` if the source is a spec file, `false` otherwise.
    def spec?
      path.ends_with?("_spec.cr")
    end

    # Returns `true` if *filepath* matches the source's path, `false` if it does not.
    def matches_path?(filepath)
      path == filepath || path == File.expand_path(filepath)
    end
  end
end
