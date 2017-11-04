require "compiler/crystal/syntax/*"

module Ameba::AST
  NODE_VISITORS = [
    Call,
    Case,
    Def,
    If,
    StringInterpolation,
    Unless,
  ]

  {% for name in NODE_VISITORS %}
    class {{name}}Visitor < Crystal::Visitor
      @rule : Rule
      @source : Source

      def initialize(@rule, @source)
        parser = Crystal::Parser.new(@source.content)
        parser.filename = @source.path
        parser.parse.accept self
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
