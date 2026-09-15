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
      if suffix?(node)
        return unless then_end_loc = node.then.end_location
        return unless cond_loc = node.cond.location

        then_end_pos = source.pos(then_end_loc, end: true)
        cond_begin_pos = source.pos(cond_loc)
        return unless offset = source.code[then_end_pos...cond_begin_pos].index("unless")

        keyword_pos = then_end_pos + offset
        keyword_range = keyword_pos...(keyword_pos + {{ "unless".size }})
      else
        return unless location = node.location

        keyword_begin_pos = source.pos(location)
        keyword_range = keyword_begin_pos...(keyword_begin_pos + {{ "unless".size }})
      end

      return unless not_loc = not_node.location
      return unless exp_loc = not_node.exp.location

      not_begin_pos = source.pos(not_loc)
      exp_begin_pos = source.pos(exp_loc)
      not_end_pos = not_loc.same_line?(exp_loc) ? exp_begin_pos : not_begin_pos + 1
      not_range = not_begin_pos...not_end_pos

      corrector.replace(keyword_range, "if")
      corrector.remove(not_range)
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
