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
  #   ExcludeTernary: true
  #   ExcludeAssignments: false
  # ```
  class RedundantParentheses < Base
    properties do
      description "Disallows redundant parentheses around control expressions"

      exclude_ternary true
      exclude_assignments false
    end

    MSG = "Redundant parentheses"

    def test(source, node : Crystal::If | Crystal::Unless | Crystal::Case | Crystal::While | Crystal::Until)
      is_ternary = node.is_a?(Crystal::If) && node.ternary?

      return if exclude_ternary && is_ternary

      return unless (cond = node.cond).is_a?(Crystal::Expressions)
      return unless cond.keyword.paren?

      return unless exp = cond.single_expression?

      case exp
      when Crystal::BinaryOp
        return if is_ternary
      when Crystal::Assign, Crystal::OpAssign
        return if exclude_assignments
      end

      issue_for cond, MSG do |corrector|
        corrector.remove_trailing(cond, 1)
        corrector.remove_leading(cond, 1)
      end
    end
  end
end
