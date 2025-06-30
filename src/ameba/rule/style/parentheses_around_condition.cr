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
  #   ExcludeMultiline: false
  #   AllowSafeAssignment: false
  # ```
  class ParenthesesAroundCondition < Base
    properties do
      since_version "1.4.0"
      description "Disallows redundant parentheses around control expressions"

      exclude_ternary false
      exclude_multiline false
      allow_safe_assignment false
    end

    MSG_REDUNDANT = "Redundant parentheses"
    MSG_MISSING   = "Missing parentheses"

    def test(source, node : Crystal::If | Crystal::Unless | Crystal::Case | Crystal::While | Crystal::Until)
      return unless cond = node.cond

      if cond.is_a?(Crystal::Assign) && allow_safe_assignment?
        issue_for cond, MSG_MISSING do |corrector|
          corrector.wrap(cond, '(', ')')
        end
        return
      end

      return unless redundant_parentheses?(node, cond)

      issue_for cond, MSG_REDUNDANT do |corrector|
        corrector.remove_trailing(cond, 1)
        corrector.remove_leading(cond, 1)
      end
    end

    private def redundant_parentheses?(node, cond) : Bool
      is_ternary = node.is_a?(Crystal::If) && node.ternary?

      return false if is_ternary && exclude_ternary?

      return false unless cond.is_a?(Crystal::Expressions)
      return false unless cond.keyword.paren?

      return false unless exp = cond.single_expression?
      return false unless strip_parentheses?(exp, is_ternary)

      if exclude_multiline?
        if (location = node.location) && (end_location = node.end_location)
          return false unless location.same_line?(end_location)
        end
      end

      true
    end

    private def strip_parentheses?(node, in_ternary) : Bool
      case node
      when Crystal::BinaryOp
        !in_ternary
      when Crystal::Call
        !in_ternary || node.has_parentheses? || node.args.empty?
      when Crystal::ExceptionHandler, Crystal::If, Crystal::Unless
        false
      when Crystal::Yield
        !in_ternary || node.has_parentheses? || node.exps.empty?
      when Crystal::Assign, Crystal::OpAssign, Crystal::MultiAssign
        !in_ternary && !allow_safe_assignment?
      else
        true
      end
    end
  end
end
