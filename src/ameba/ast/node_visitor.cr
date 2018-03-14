require "./base_visitor"

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
  # visitor = Ameba::AST::NodeVisitor.new(rule, source)
  # ```
  #
  class NodeVisitor < BaseVisitor
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
