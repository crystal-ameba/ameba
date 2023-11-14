require "./base_visitor"

module Ameba::AST
  # An AST Visitor that traverses the source and allows all nodes
  # to be inspected by rules.
  #
  # ```
  # visitor = Ameba::AST::NodeVisitor.new(rule, source)
  # ```
  class NodeVisitor < BaseVisitor
    @[Flags]
    enum Category
      Macro
    end

    # List of nodes to be visited by Ameba's rules.
    NODES = {
      Alias,
      Assign,
      Block,
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
      IsA,
      LibDef,
      ModuleDef,
      MultiAssign,
      NilLiteral,
      StringInterpolation,
      Unless,
      Until,
      Var,
      When,
      While,
    }

    @skip : Array(Crystal::ASTNode.class)?

    def self.category_to_node_classes(category : Category)
      ([] of Crystal::ASTNode.class).tap do |classes|
        classes.push(
          Crystal::Macro,
          Crystal::MacroExpression,
          Crystal::MacroIf,
          Crystal::MacroFor,
        ) if category.macro?
      end
    end

    def initialize(@rule, @source, *, skip : Category)
      initialize @rule, @source,
        skip: NodeVisitor.category_to_node_classes(skip)
    end

    def initialize(@rule, @source, *, skip : Array? = nil)
      @skip = skip.try &.map(&.as(Crystal::ASTNode.class))
      super @rule, @source
    end

    def visit(node : Crystal::VisibilityModifier)
      node.exp.visibility = node.modifier
      true
    end

    {% for name in NODES %}
      # A visit callback for `Crystal::{{ name }}` node.
      #
      # Returns `true` if the child nodes should be traversed as well,
      # `false` otherwise.
      def visit(node : Crystal::{{ name }})
        return false if skip?(node)

        @rule.test @source, node
        true
      end
    {% end %}

    def visit(node)
      !skip?(node)
    end

    private def skip?(node)
      !!@skip.try(&.includes?(node.class))
    end
  end
end
