module Ameba::AST
  class Scope
    def initialize(@node : Crystal::ASTNode)
      @vars, @assigns = VarVisitor.new(@node).vars_and_assigns
    end

    private class VarVisitor < Crystal::Visitor
      getter vars = [] of Crystal::Var
      getter assigns = [] of Crystal::Assign

      def initialize(ast_node)
        ast_node.accept self
      end

      def visit(node : Crystal::ASTNode)
        true
      end

      def visit(node : Crystal::Assign)
        @vars << node
        false
      end

      def visit(node : Crystal::Var)
        @assigns << node
        false
      end

      def vars_and_assigns
        {vars, assigns}
      end
    end
  end
end
