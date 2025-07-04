module Ameba::Rule::Style
  # A rule that disallows negated conditions in `unless`.
  #
  # For example, this is considered invalid:
  #
  # ```
  # unless !s.empty?
  #   :ok
  # end
  # ```
  #
  # And should be rewritten to the following:
  #
  # ```
  # if s.empty?
  #   :ok
  # end
  # ```
  #
  # It is pretty difficult to wrap your head around a block of code
  # that is executed if a negated condition is NOT met.
  #
  # YAML configuration example:
  #
  # ```
  # Style/NegatedConditionsInUnless:
  #   Enabled: true
  # ```
  class NegatedConditionsInUnless < Base
    properties do
      since_version "0.2.0"
      description "Disallows negated conditions in `unless`"
    end

    MSG = "Avoid negated conditions in unless blocks"

    def test(source, node : Crystal::Unless)
      issue_for node, MSG if negated_condition?(node.cond)
    end

    private def negated_condition?(node)
      case node
      when Crystal::BinaryOp
        negated_condition?(node.left) || negated_condition?(node.right)
      when Crystal::Expressions
        node.expressions.any? { |exp| negated_condition?(exp) }
      when Crystal::Not
        true
      else
        false
      end
    end
  end
end
