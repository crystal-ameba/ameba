require "./base_visitor"

module Ameba::AST
  class ScopeVisitor < BaseVisitor
    @current_scope : Scope?

    private def on_scope_enter(node)
      @current_scope = Scope.new(node, @current_scope)
    end

    private def on_scope_end(node)
      @rule.test @source, node, @current_scope
      @current_scope = @current_scope.try &.parent
    end

    def visit(node : Crystal::Def)
      on_scope_enter(node)
      true
    end

    def end_visit(node : Crystal::Def)
      on_scope_end(node)
    end

    def visit(node : Crystal::ProcLiteral)
      on_scope_enter(node)
      true
    end

    def end_visit(node : Crystal::ProcLiteral)
      on_scope_end(node)
    end
  end
end
