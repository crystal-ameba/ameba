module Ameba::Rule
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
  # EmptyExpression:
  #   Enabled: true
  # ```
  #
  struct EmptyExpression < Base
    include AST::Util

    properties do
      description "Disallows empty expressions"
    end

    def test(source)
      AST::NodeVisitor.new self, source
    end

    def test(source, node : Crystal::NilLiteral)
      exp = node_source(node, source.lines).try &.join

      return if exp.nil? || exp == "nil"

      source.error self, node.location, "Avoid empty expression '#{exp}'"
    end

    def test(source, node : Crystal::Expressions)
      if node.expressions.size == 1 && node.expressions.first.nop?
        source.error self, node.location, "Avoid empty expressions"
      end
    end
  end
end
