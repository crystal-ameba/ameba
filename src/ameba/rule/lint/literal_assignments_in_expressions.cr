module Ameba::Rule::Lint
  # A rule that disallows assignments with literal values
  # in control expressions.
  #
  # For example, this is considered invalid:
  #
  # ```
  # if foo = 42
  #   do_something
  # end
  # ```
  #
  # And most likely should be replaced by the following:
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
  # Lint/LiteralAssignmentsInExpressions:
  #   Enabled: true
  # ```
  class LiteralAssignmentsInExpressions < Base
    include AST::Util

    properties do
      description "Disallows assignments with literal values in control expressions"
    end

    MSG = "Detected assignment with a literal value in control expression"

    def test(source, node : Crystal::If | Crystal::Unless | Crystal::Case | Crystal::While | Crystal::Until)
      return unless (cond = node.cond).is_a?(Crystal::Assign)
      return unless literal?(cond.value)

      issue_for cond, MSG
    end
  end
end
