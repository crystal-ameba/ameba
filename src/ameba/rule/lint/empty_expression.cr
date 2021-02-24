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
    include AST::Util

    properties do
      enabled false
      description "Disallows empty expressions"
    end

    MSG      = "Avoid empty expression %s"
    MSG_EXRS = "Avoid empty expressions"

    def test(source, node : Crystal::NilLiteral)
      exp = node_source(node, source.lines).try &.join
      return if exp.in?(nil, "nil")

      issue_for node, MSG % exp
    end

    def test(source, node : Crystal::Expressions)
      if node.expressions.size == 1 && node.expressions.first.nop?
        issue_for node, MSG_EXRS
      end
    end
  end
end
