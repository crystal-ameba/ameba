module Ameba::AST
  class Scope < Crystal::Visitor
    getter assigns = [] of Crystal::Assign
    getter assign_var_table = {} of Crystal::Assign => Array(Crystal::Var)

    def initialize(@node : Crystal::ASTNode)
      @node.accept self
    end

    def unused_var?(assign)
      return false unless assign.target.is_a?(Crystal::Var)
      assign_var_table[assign].size < 2
    end

    def visit(node : Crystal::ASTNode)
      true
    end

    def visit(node : Crystal::Assign)
      @assigns << node
    end

    def visit(node : Crystal::Var)
      if last_assign = @assigns.last?
        (assign_var_table[last_assign] ||= Array(Crystal::Var).new) << node
      end

      false
    end
  end
end
