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
    getter ast : Crystal::ASTNode?

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

    def ast
      @ast ||= Crystal::Parser.new(@content)
                              .tap { |p| p.filename = @path }
                              .parse
    end

    def lexer
      Crystal::Lexer.new(@content).tap do |l|
        l.count_whitespace = true
        l.comments_enabled = true
        l.wants_raw = true
      end
    end
  end
end
