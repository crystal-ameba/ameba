module Ameba::Rule
  # A rule that reports invalid Crystal syntax.
  #
  # For example, this syntax is invalid:
  #
  # ```
  # def hello
  #   do_something
  # rescue Exception => e
  # end
  # ```
  #
  # And should be properly written:
  #
  # ```
  # def hello
  #   do_something
  # rescue e : Exception
  # end
  # ```
  #
  struct Syntax < Base
    def test(source)
      source.ast
    rescue e : Crystal::SyntaxException
      location = source.location(e.line_number, e.column_number)
      source.error self, location, e.message.to_s
    end
  end
end
