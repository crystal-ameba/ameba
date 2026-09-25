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
    include AST::Util

    properties do
      since_version "0.2.0"
      description "Disallows negated conditions in `unless`"
    end

    MSG = "Avoid negated conditions in `unless` blocks"

    def test(source, node : Crystal::Unless)
      return unless negated_condition?(node.cond)

      if (not_node = node.cond).is_a?(Crystal::Not)
        issue_for(node, MSG) do |corrector|
          correct(corrector, source, node, not_node)
        end
      else
        issue_for(node, MSG)
      end
    end

    private def correct(corrector, source, node, not_node)
      return unless node_location = node.location
      return unless not_node_location = not_node.location

      if suffix?(node)
        return unless idx = source.lines[node_location.line_number - 1].index("unless")
        node_location = node_location.with(column_number: idx + 1)
      end

      corrector.replace(
        node_location,
        node_location.adjust(column_number: {{ "unless".size - 1 }}),
        "if",
      )
      corrector.remove(not_node_location, not_node_location)
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
