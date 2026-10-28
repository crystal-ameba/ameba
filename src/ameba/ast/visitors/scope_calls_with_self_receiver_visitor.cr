module Ameba::AST
  class ScopeCallsWithSelfReceiverVisitor < Crystal::Visitor
    include ScopeBuilding

    getter scope_call_queue = {} of AST::Scope => Array(Crystal::Call)

    def initialize(rule, source)
      @current_scope = AST::Scope.new(source.ast) # top level scope

      source.ast.accept(self)

      scope_call_queue.each do |scope, calls|
        calls.each do |call|
          rule.test(source, call, scope)
        end
      end
    end

    private def on_scope_enter(node)
      scope = AST::Scope.new(node, @current_scope)

      @current_scope = scope
      true
    end

    private def on_scope_end(node)
      # go up if this is not a top level scope
      if outer_scope = @current_scope.outer_scope
        @current_scope = outer_scope
      end
    end

    def visit(node : Crystal::Block | Crystal::ProcLiteral)
      on_scope_enter(node)
    end

    def visit(node : Crystal::ClassDef | Crystal::ModuleDef)
      on_scope_enter(node)
    end

    def visit(node : Crystal::Call)
      if (obj = node.obj).is_a?(Crystal::Var) && obj.name == "self"
        calls = @scope_call_queue[@current_scope] ||= [] of Crystal::Call
        calls << node
      end
      true
    end
  end
end
