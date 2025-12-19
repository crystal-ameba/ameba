module Ameba::Rule::Lint
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
    end
  end
end
