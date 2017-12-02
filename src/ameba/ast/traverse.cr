require "compiler/crystal/syntax/*"

# A module that helps to traverse Crystal AST using `Crystal::Visitor`.
module Ameba::AST
  # List of nodes to be visited by Ameba's rules.
  NODES = [
    Alias,
    Assign,
    Call,
    Case,
    ClassDef,
    ClassVar,
    Def,
    EnumDef,
    ExceptionHandler,
    Expressions,
    HashLiteral,
    If,
    InstanceVar,
    LibDef,
    ModuleDef,
    NilLiteral,
    StringInterpolation,
    Unless,
    Var,
    When,
    While,
  ]

  # An AST Visitor used by rules.
  #
  # ```
  # visitor = Ameba::AST::Visitor.new(rule, source)
  # ```
  #
  class Visitor < Crystal::Visitor
    # A corresponding rule that uses this visitor.
    @rule : Rule::Base

    # A source that needs to be traversed.
    @source : Source

    # Creates instance of this visitor.
    #
    # ```
    # visitor = Ameba::AST::Visitor.new(rule, source)
    # ```
    #
    def initialize(@rule, @source)
      @source.ast.accept self
    end

    # A main visit method that accepts `Crystal::ASTNode`.
    # Returns true meaning all child nodes will be traversed.
    def visit(node : Crystal::ASTNode)
      true
    end

    {% for name in NODES %}
      # A visit callback for `Crystal::{{name}}` node.
      # Returns true meaning that child nodes will be traversed as well.
      def visit(node : Crystal::{{name}})
        @rule.test @source, node
        true
      end
    {% end %}
  end
end
