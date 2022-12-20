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
      description "Reports not formatted sources"
      fail_on_error false
    end

    MSG       = "Use built-in formatter to format this source"
    MSG_ERROR = "Error while formatting: %s"

    private LOCATION = {1, 1}

    def test(source)
      source_code = source.code
      result = Crystal.format(source_code, source.path)
      return if result == source_code

      source_lines = source_code.lines
      return if source_lines.empty?

      end_location = {
        source_lines.size,
        source_lines.last.size + 1,
      }

      issue_for LOCATION, MSG do |corrector|
        corrector.replace(LOCATION, end_location, result)
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
