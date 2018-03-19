require "./base_visitor"

module Ameba::AST
  # AST Visitor that traverses the source and constructs scopes.
  class ScopeVisitor < BaseVisitor
    @current_scope : Scope?

    private def on_scope_enter(node)
      @current_scope = Scope.new(node, @current_scope)
    end

    private def on_scope_end(node)
      @rule.test @source, node, @current_scope
      @current_scope = @current_scope.try &.outer_scope
    end

    # :nodoc:
    def visit(node : Crystal::Def)
      on_scope_enter(node)
      true
    end

    # :nodoc:
    def end_visit(node : Crystal::Def)
      on_scope_end(node)
    end

    # :nodoc:
    def visit(node : Crystal::Block)
      on_scope_enter(node)
      true
    end

    # :nodoc:
    def end_visit(node : Crystal::Block)
      on_scope_end(node)
    end
  end
end
