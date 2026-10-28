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

    MSG = "Avoid negated conditions in `unless` blocks"

    def test(source, node : Crystal::Unless)
      cond = node.cond
      return unless negated_condition?(cond)

      if cond.is_a?(Crystal::Not)
        issue_for(cond, MSG) do |corrector|
          correct(corrector, source, cond)
        end
      else
        issue_for(cond, MSG)
      end
    end

    private def correct(corrector, source, not_node)
      return unless location = not_node.location

      # The `unless` keyword is directly followed by the negated condition,
      # both in the regular and in the suffix form
      code = source.code
      not_pos = source.pos(location)

      return unless keyword_pos = code.rindex("unless", not_pos - {{ "unless".size }})
      keyword_range = keyword_pos...keyword_pos + {{ "unless".size }}

      return unless code[keyword_range.end...not_pos].blank?

      corrector.replace(keyword_range, "if")
      corrector.remove(location, location)
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
