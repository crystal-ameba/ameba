require "compiler/crystal/syntax/*"

module Ameba::AST
  NODE_VISITORS = [
    Alias,
    Assign,
    Call,
    Case,
    ClassDef,
    ClassVar,
    Def,
    EnumDef,
    If,
    InstanceVar,
    LibDef,
    ModuleDef,
    NilLiteral,
    StringInterpolation,
    Unless,
    Var,
  ]

  class Visitor < Crystal::Visitor
    @rule : Rule::Base
    @source : Source

    def initialize(@rule, @source)
      @source.ast.accept self
    end

    def visit(node : Crystal::ASTNode)
      true
    end

    {% for name in NODE_VISITORS %}
      def visit(node : Crystal::{{name}})
        @rule.test @source, node
        true
      end
    {% end %}
  end
end
