module Ameba::Rule::Lint
  # A rule that disallows empty expressions.
  #
  # This is considered invalid:
  #
  # ```
  # foo = ()
  #
  # if ()
  #   bar
  # end
  # ```
  #
  # And this is valid:
  #
  # ```
  # foo = (some_expression)
  #
  # if (some_expression)
  #   bar
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/EmptyExpression:
  #   Enabled: true
  # ```
  class EmptyExpression < Base
    properties do
      description "Disallows empty expressions"
    end

    MSG = "Avoid empty expressions"

    def test(source, node : Crystal::Expressions)
      return unless node.expressions.size == 1 && node.expressions.first.nop?
      issue_for node, MSG
    end
  end
end
