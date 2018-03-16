module Ameba::AST
  class Scope
    getter assigns = [] of Crystal::Assign
    getter assign_var_table = {} of Crystal::Assign => Array(Crystal::Var)
    getter parent : Scope?
    getter node : Crystal::ASTNode

    def initialize(@node, @parent)
      @node.accept VariableVisitor.new(self)
    end

    def assigns_var?(assign)
      assign_var_table[assign]?.try &.size.> 1
    end

    def unused_var?(assign)
      return false unless assign.target.is_a?(Crystal::Var)
      return false if parent.try &.assigns_var?(assign)
      !assigns_var?(assign)
    end

    private class VariableVisitor < Crystal::Visitor
      def initialize(@scope : Scope)
      end

      def visit(node : Crystal::ASTNode)
        true
      end

      def visit(node : Crystal::Assign)
        @scope.assigns << node
        true
      end

      def visit(node : Crystal::Var)
        @scope.assigns
              .select { |a| (t = a.target) && t.is_a?(Crystal::Var) && t.name == node.name }
              .each do |assign|
          (@scope.assign_var_table[assign] ||= Array(Crystal::Var).new) << node
        end

        false
      end
    end
  end
end
