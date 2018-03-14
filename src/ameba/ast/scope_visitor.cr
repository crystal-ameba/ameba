require "./base_visitor"

module Ameba::AST
  class ScopeVisitor < BaseVisitor
    private def process_node(node)
      @rule.test @source, node, Scope.new(node)
    end

    def visit(node : Crystal::Def)
      process_node(node)
      true
    end

    def visit(node : Crystal::ProcLiteral)
      process_node(node)
      true
    end

    def visit(node : Crystal::Block)
      process_node(node)
      true
    end
  end
end
