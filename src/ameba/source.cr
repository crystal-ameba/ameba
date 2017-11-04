module Ameba
  # An entity that represents a Crystal source file.
  # Has path, lines of code and errors reported by rules.
  class Source
    # Represents an error caught by Ameba.
    #
    # Each error has the rule that created this error,
    # position of the error and a message.
    record Error,
      rule : Rule,
      pos : Int32?,
      message : String

    getter lines : Array(String)?
    getter errors = [] of Error
    getter path : String?
    getter content : String

    def initialize(@content : String, @path = nil)
    end

    def error(rule : Rule, line_number : Int32?, message : String)
      errors << Error.new rule, line_number, message
    end

    def valid?
      errors.empty?
    end

    def lines
      @lines ||= @content.split("\n")
    end
  end
end
