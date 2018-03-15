module Ameba::AST
  class Scope < Crystal::Visitor
    getter assigns = [] of Crystal::Assign
    getter variable_table = {} of Crystal::Assign => Array(Crystal::Var)

    def initialize(@node : Crystal::ASTNode)
      @node.accept self
    end

    def used?(assign : Crystal::Assign)
      variable_table[assign].size > 1
    end

    def visit(node : Crystal::ASTNode)
      true
    end

    def visit(node : Crystal::Assign)
      @assigns << node
    end

    def visit(node : Crystal::Var)
      last_assign = @assigns.last
      (variable_table[last_assign] ||= Array(Crystal::Var).new) << node

      false
    end
  end
end
