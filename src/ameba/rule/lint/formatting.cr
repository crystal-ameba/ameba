require "compiler/crystal/formatter"

module Ameba::Rule::Lint
  # A rule that verifies syntax formatting according to the
  # Crystal's built-in formatter.
  #
  # For example, this syntax is invalid:
  #
  #     def foo(a,b,c=0)
  #       #foobar
  #       a+b+c
  #     end
  #
  # And should be properly written:
  #
  #     def foo(a, b, c = 0)
  #       # foobar
  #       a + b + c
  #     end
  #
  # YAML configuration example:
  #
  # ```
  # Lint/Formatting:
  #   Enabled: true
  #   FailOnError: false
  # ```
  class Formatting < Base
    properties do
      since_version "1.4.0"
      description "Reports unformatted sources"
      fail_on_error false
    end

    MSG       = "Use built-in formatter to format this source"
    MSG_ERROR = "Error while formatting: %s"

    private LOCATION = {1, 1}

    def test(source)
      source_code = source.code
      return if source_code.empty?

      result = Crystal.format(source_code, source.path)
      return if result == source_code

      issue_for(LOCATION, MSG) do |corrector|
        corrector.replace(0...source_code.size, result)
      end
    rescue ex : Crystal::SyntaxException
      if fail_on_error?
        issue_for({ex.line_number, ex.column_number}, MSG_ERROR % ex.message)
      end
    rescue ex
      if fail_on_error?
        issue_for(LOCATION, MSG_ERROR % ex.message)
      end
    end
  end
end
