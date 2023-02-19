module Ameba::Rule::Style
  # A rule that checks for the presence of superfluous parentheses
  # around the condition of `if`, `unless`, `case`, `while` and `until`.
  #
  # For example, this is considered invalid:
  #
  # ```
  # if (foo == 42)
  #   do_something
  # end
  # ```
  #
  # And should be replaced by the following:
  #
  # ```
  # if foo == 42
  #   do_something
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/ParenthesesAroundCondition:
  #   Enabled: true
  #   ExcludeTernary: false
  #   AllowSafeAssignment: false
  # ```
  class ParenthesesAroundCondition < Base
    properties do
      description "Disallows redundant parentheses around control expressions"

      exclude_ternary false
      allow_safe_assignment false
    end

    MSG_REDUNDANT = "Redundant parentheses"
    MSG_MISSING   = "Missing parentheses"

    protected def strip_parentheses?(node, in_ternary) : Bool
      case node
      when Crystal::BinaryOp, Crystal::ExceptionHandler
        !in_ternary
      when Crystal::Call
        !in_ternary || node.has_parentheses? || node.args.empty?
      when Crystal::Yield
        !in_ternary || node.has_parentheses? || node.exps.empty?
      when Crystal::Assign, Crystal::OpAssign, Crystal::MultiAssign
        !in_ternary && !allow_safe_assignment?
      else
        true
      end
    end

    def test(source, node : Crystal::If | Crystal::Unless | Crystal::Case | Crystal::While | Crystal::Until)
      cond = node.cond

      if cond.is_a?(Crystal::Assign) && allow_safe_assignment?
        issue_for cond, MSG_MISSING do |corrector|
          corrector.wrap(cond, '(', ')')
        end
        return
      end

      is_ternary = node.is_a?(Crystal::If) && node.ternary?

      return if is_ternary && exclude_ternary?

      return unless cond.is_a?(Crystal::Expressions)
      return unless cond.keyword.paren?

      return unless exp = cond.single_expression?
      return unless strip_parentheses?(exp, is_ternary)

      issue_for cond, MSG_REDUNDANT do |corrector|
        corrector.remove_trailing(cond, 1)
        corrector.remove_leading(cond, 1)
      end
    end
  end
end
