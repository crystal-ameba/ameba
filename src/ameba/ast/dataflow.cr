module Ameba::AST
  # Building blocks for dataflow analysis: the AST node groupings used to
  # generate type-specific handlers, body extraction, and immediate-child
  # collection.
  module Dataflow
    BRANCH_NODES      = %w[If Unless]
    LOOP_NODES        = %w[While Until]
    CASE_NODES        = %w[Case Select]
    INNER_SCOPE_NODES = %w[
      Block Def ProcLiteral ClassDef ModuleDef EnumDef
      LibDef FunDef TypeDef CStructOrUnionDef TypeOf
      Macro MacroIf MacroFor
    ]

    # Returns the body node a scope analysis should walk for *node*.
    # ameba:disable Metrics/CyclomaticComplexity
    def scope_body(node)
      case node
      when Crystal::Def               then node.body
      when Crystal::FunDef            then node.body
      when Crystal::Block             then node.body
      when Crystal::ClassDef          then node.body
      when Crystal::ModuleDef         then node.body
      when Crystal::LibDef            then node.body
      when Crystal::CStructOrUnionDef then node.body
      when Crystal::Assign            then node.value
      when Crystal::OpAssign          then node.value
      when Crystal::ProcLiteral       then node.def.body
      when Crystal::EnumDef           then Crystal::Expressions.from(node.members)
      when Crystal::TypeOf            then Crystal::Expressions.from(node.expressions)
      when Crystal::Expressions       then node
      else                                 node
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
