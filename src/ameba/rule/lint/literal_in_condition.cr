module Ameba::Rule::Lint
  # A rule that disallows useless conditional statements that contain a literal
  # in place of a variable or predicate function.
  #
  # This is because a conditional construct with a literal predicate will
  # always result in the same behavior at run time, meaning it can be
  # replaced with either the body of the construct, or deleted entirely.
  #
  # This is considered invalid:
  #
  # ```
  # if "something"
  #   :ok
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/LiteralInCondition:
  #   Enabled: true
  # ```
  class LiteralInCondition < Base
    include AST::Util

    properties do
      since_version "0.1.0"
      description "Disallows useless conditional statements that contain \
        a literal in place of a variable or predicate function"
    end

    MSG = "Literal value found in conditional"

    def test(source, node : Crystal::If | Crystal::Unless | Crystal::Until)
      issue_for node.cond, MSG if literal?(node.cond)
    end

    def test(source, node : Crystal::Case)
      return unless cond = node.cond
      return unless static_literal?(cond)

      issue_for cond, MSG
    end

    def test(source, node : Crystal::While)
      return unless cond = node.cond
      return unless literal?(cond)

      # allow `while true`
      return if cond.is_a?(Crystal::BoolLiteral) && cond.value

      issue_for cond, MSG
    end
  end
end
