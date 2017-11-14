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

    def test(source)
      AST::Visitor.new self, source
    end

    def test(source, node : Crystal::NilLiteral)
      exp = node_source(node, source.lines).try &.join

      return if exp.nil? || exp == "nil"

      source.error self, node.location, "Avoid empty expression '#{exp}'"
    end
  end
end
