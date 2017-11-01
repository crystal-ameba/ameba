require "compiler/crystal/syntax/*"

module Ameba::AST
  NODE_VISITORS = [
    Call,
    Case,
    If,
    StringInterpolation,
    Unless,
  ]

  {% for name in NODE_VISITORS %}
    class {{name}}Visitor < Crystal::Visitor
      @rule : Rule
      @source : Source

      def initialize(@rule, @source)
        @source.ast.accept self
      end

      def visit(node : Crystal::ASTNode)
        true
      end

      def visit(node : Crystal::{{name}})
        @rule.test @source, node
      end
    end
  {% end %}
end
