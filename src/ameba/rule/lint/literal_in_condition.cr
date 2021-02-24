module Ameba::Rule::Lint
  # A rule that disallows useless conditional statements that contain a literal
  # in place of a variable or predicate function.
  #
  # This is because a conditional construct with a literal predicate will
  # always result in the same behaviour at run time, meaning it can be
  # replaced with either the body of the construct, or deleted entirely.
  #
  # This is considered invalid:
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
      description "Disallows useless conditional statements that contain \
        a literal in place of a variable or predicate function"
    end

    MSG = "Literal value found in conditional"

    def check_node(source, node)
      issue_for node, MSG if literal?(node.cond)
    end

    def test(source, node : Crystal::If)
      check_node source, node
    end

    def test(source, node : Crystal::Unless)
      check_node source, node
    end

    def test(source, node : Crystal::Case)
      check_node source, node
    end
  end
end
