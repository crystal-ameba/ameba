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

    getter lines : Array(String)?
    getter errors = [] of Error
    getter path : String?
    getter code : String
    getter ast : Crystal::ASTNode?

    def initialize(@code : String, @path = nil)
    end

    def error(rule : Rule::Base, location, message : String)
      errors << Error.new rule, location, message
    end

    def valid?
      errors.empty?
    end

    def lines
      @lines ||= @code.split("\n")
    end

    def ast
      @ast ||=
        Crystal::Parser.new(code)
                       .tap { |parser| parser.filename = @path }
                       .parse
    end

    def location(l, c)
      Crystal::Location.new path, l, c
    end
  end
end
