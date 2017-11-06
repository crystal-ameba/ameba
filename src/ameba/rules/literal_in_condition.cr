module Ameba::Rules
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
  struct LiteralInCondition < Rule
    include AST::Util

    def test(source)
      AST::Visitor.new self, source
    end

    def check_node(source, node)
      return unless literal?(node.cond)
      source.error self, node.location.try &.line_number,
        "Literal value found in conditional"
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
