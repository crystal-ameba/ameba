module Ameba::Rule::Lint
  # A rule that reports invalid Crystal syntax.
  #
  # For example, this syntax is invalid:
  #
  # ```
  # def hello
  #   do_something
  # rescue Exception => ex
  # end
  # ```
  #
  # And should be properly written:
  #
  # ```
  # def hello
  #   do_something
  # rescue ex : Exception
  # end
  # ```
  class Syntax < Base
    properties do
      since_version "0.4.2"
      description "Reports invalid Crystal syntax"
      severity :error
    end

    def test(source)
      source.ast
    rescue ex : Crystal::SyntaxException
      issue_for({ex.line_number, ex.column_number}, ex.message.to_s)
    rescue ex : InvalidByteSequenceError
      issue_for(invalid_byte_location(source.code), ex.message.to_s)
    end

    # Returns the line and column of the first byte in *code* which
    # isn't valid UTF-8, counting the characters before it. Falls back to
    # the start of the code if there's no such byte.
    private def invalid_byte_location(code) : {Int32, Int32}
      reader = Char::Reader.new(code)
      line_number = column_number = 1

      while reader.has_next?
        return {line_number, column_number} if reader.error

        if reader.current_char == '\n'
          line_number += 1
          column_number = 1
        else
          column_number += 1
        end
        reader.next_char
      end

      {1, 1}
    end
  end
end
