module Ameba::AST
  class ScopeCallsWithSelfReceiverVisitor < Crystal::Visitor
    include ScopeBuilding

    getter scope_call_queue = {} of AST::Scope => Array(Crystal::Call)

    # Scopes in which the type of `self` gets narrowed down
    # (i.e. via `is_a?`, `responds_to?`, `nil?` or `case self`).
    getter self_narrowing_scopes = Set(AST::Scope).new

    def initialize(rule, source)
      @current_scope = AST::Scope.new(source.ast) # top level scope

      source.ast.accept(self)

      scope_call_queue.each do |scope, calls|
        next if self_narrowed?(scope)

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

    # Returns `true` if the type of `self` is narrowed within the *scope*,
    # or any of its outer scopes within the enclosing method or type definition.
    private def self_narrowed?(scope)
      while scope
        return true if scope.in?(self_narrowing_scopes)
        break if scope.type_definition? || !scope.inherited?

        scope = scope.outer_scope
      end
      false
    end

    private def self_var?(node)
      node.is_a?(Crystal::Var) && node.name == "self"
    end

    def visit(node : Crystal::IsA | Crystal::RespondsTo)
      self_narrowing_scopes << @current_scope if self_var?(node.obj)
      true
    end

    def visit(node : Crystal::Case)
      self_narrowing_scopes << @current_scope if self_var?(node.cond)
      true
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
