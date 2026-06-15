module Ameba::AST
  # Building blocks for dataflow analysis: the AST node groupings used to
  # generate type-specific handlers, body extraction, and immediate-child
  # collection.
  module Dataflow
    private BRANCH_NODES      = %w[If Unless]
    private LOOP_NODES        = %w[While Until]
    private CASE_NODES        = %w[Case Select]
    private INNER_SCOPE_NODES = %w[
      Block Def ProcLiteral ClassDef ModuleDef EnumDef
      LibDef FunDef TypeDef CStructOrUnionDef TypeOf
      Macro MacroIf MacroFor
    ]

    # Returns the body node a scope analysis should walk for *node*.
    def scope_body(node)
      case node
      when Crystal::Def,
           Crystal::FunDef,
           Crystal::Block,
           Crystal::ClassDef,
           Crystal::ModuleDef,
           Crystal::LibDef,
           Crystal::CStructOrUnionDef
        node.body
      when Crystal::Assign, Crystal::OpAssign
        node.value
      when Crystal::ProcLiteral then node.def.body
      when Crystal::EnumDef     then Crystal::Expressions.from(node.members)
      when Crystal::TypeOf      then Crystal::Expressions.from(node.expressions)
      when Crystal::Expressions then node
      else                           node
      end
    end

    # Collects the immediate children of a node without descending into them.
    class ChildCollector < Crystal::Visitor
      def initialize(@children : Array(Crystal::ASTNode))
      end

      def visit(node : Crystal::ASTNode)
        @children << node
        false
      end
    end
  end
end
