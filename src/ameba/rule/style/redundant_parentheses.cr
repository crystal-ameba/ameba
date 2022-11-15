module Ameba::Rule::Style
  # A rule that disallows redundant parentheses around control expressions.
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
  # Style/RedundantParentheses:
  #   Enabled: true
  #   ExcludeTernary: false
  #   ExcludeAssignments: false
  # ```
  class RedundantParentheses < Base
    properties do
      description "Disallows redundant parentheses around control expressions"

      exclude_ternary false
      exclude_assignments false
    end

    MSG = "Redundant parentheses"

    protected def strip_parentheses?(node, in_ternary) : Bool
      case node
      when Crystal::BinaryOp, Crystal::ExceptionHandler
        !in_ternary
      when Crystal::Call
        !in_ternary || node.has_parentheses? || node.args.empty?
      when Crystal::Yield
        !in_ternary || node.has_parentheses? || node.exps.empty?
      when Crystal::Assign, Crystal::OpAssign, Crystal::MultiAssign
        !in_ternary && !exclude_assignments
      else
        true
      end
    end

    def test(source, node : Crystal::If | Crystal::Unless | Crystal::Case | Crystal::While | Crystal::Until)
      is_ternary = node.is_a?(Crystal::If) && node.ternary?

      return if is_ternary && exclude_ternary

      return unless (cond = node.cond).is_a?(Crystal::Expressions)
      return unless cond.keyword.paren?

      return unless exp = cond.single_expression?
      return unless strip_parentheses?(exp, is_ternary)

      issue_for cond, MSG do |corrector|
        corrector.remove_trailing(cond, 1)
        corrector.remove_leading(cond, 1)
      end
    end
  end
end