module Ameba
  # An entity that represents a Crystal source file.
  # Has path, lines of code and errors reported by rules.
  class Source
    # Represents an error caught by Ameba.
    #
    # Each error has the rule that created this error,
    # location of the issue and a message.
    record Error,
      rule : Rule::Base,
      location : Crystal::Location?,
      message : String

    # Path to the source file.
    getter path : String?

    # Crystal code (content of a source file).
    getter code : String

    # List of errors reported.
    getter errors = [] of Error

    @lines : Array(String)?
    @ast : Crystal::ASTNode?

    # Creates a new source by `code` and `path`.
    #
    # For example:
    #
    # ```
    # path = "./src/source.cr"
    # Ameba::Source.new File.read(path), path
    # ```
    #
    def initialize(@code : String, @path = nil)
    end

    # Add new error to the list of errors.
    #
    # ```
    # source.error rule, location, "Line too long"
    # ```
    #
    def error(rule : Rule::Base, location, message : String)
      errors << Error.new rule, location, message
    end

    # Indicates whether source is valid or not.
    # Returns true if the list or errors empty, false otherwise.
    #
    # ```
    # source = Ameba::Source.new code, path
    # source.valid? # => true
    # source.error rule, location, message
    # source.valid? # => false
    # ```
    #
    def valid?
      errors.empty?
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
    def lines
      @lines ||= @code.split("\n")
    end

    # Returns AST nodes constructed by `Crystal::Parser`.
    #
    # ```
    # source = Ameba::Source.new code, path
    # source.ast
    # ```
    #
    def ast
      @ast ||=
        Crystal::Parser.new(code)
                       .tap { |parser| parser.filename = @path }
                       .parse
    end

    # Returns a new instance of the `Crystal::Location` in current
    # source based on the line number `l` and column number `c`.
    #
    # ```
    # s = Ameba::Source.new code, path
    # s.location(3, 76)
    # ```
    #
    def location(l, c)
      Crystal::Location.new path, l, c
    end
  end
end
