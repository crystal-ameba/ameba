require "compiler/crystal/syntax/*"

module Ameba::AST
  NODE_VISITORS = [
    Alias,
    Call,
    Case,
    ClassDef,
    Def,
    EnumDef,
    If,
    LibDef,
    ModuleDef,
    StringInterpolation,
    Unless,
  ]

  abstract class Visitor < Crystal::Visitor
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
  end

  {% for name in NODE_VISITORS %}
    class {{name}}Visitor < Visitor
      def visit(node : Crystal::{{name}})
        @rule.test @source, node
      end
    end
  {% end %}
end
