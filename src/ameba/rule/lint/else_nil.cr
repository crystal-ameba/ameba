module Ameba::Rule::Lint
  # A rule that disallows `else` blocks with `nil` as their body, as they
  # have no effect and can be safely removed.
  #
  # This is considered invalid:
  #
  # ```
  # if foo
  #   do_foo
  # else
  #   nil
  # end
  # ```
  #
  # And this is valid:
  #
  # ```
  # if foo
  #   do_foo
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/ElseNil:
  #   Enabled: true
  # ```
  class ElseNil < Base
    properties do
      since_version "1.7.0"
      description "Disallows `else` blocks with `nil` as their body"
    end

    MSG = "Avoid `else` blocks with `nil` as their body"

    def test(source, node : Crystal::Case)
      check_issue(source, node) unless node.exhaustive?
    end

    def test(source, node : Crystal::If)
      check_issue(source, node) unless node.ternary?
    end

    def test(source, node : Crystal::Unless)
      check_issue(source, node)
    end

    private def check_issue(source, node)
      return unless node_else = node.else
      return unless node_else.is_a?(Crystal::NilLiteral)

      if node.responds_to?(:else_location) &&
         (else_location = node.else_location) &&
         (end_location = node.end_location)
        issue_for node_else, MSG do |corrector|
          corrector.remove(
            else_location,
            end_location.adjust(column_number: -{{ "end".size }})
          )
        end
      else
        issue_for node_else, MSG
      end
    end
  end
end
