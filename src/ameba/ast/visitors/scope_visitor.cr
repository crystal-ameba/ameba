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
      node.name == "->" || on_scope_enter(node)
    end

    # :nodoc:
    def end_visit(node : Crystal::Def)
      node.name == "->" || on_scope_end(node)
    end

    # :nodoc:
    def visit(node : Crystal::ProcLiteral)
      on_scope_enter(node)
    end

    # :nodoc:
    def end_visit(node : Crystal::ProcLiteral)
      on_scope_end(node)
    end

    # :nodoc:
    def visit(node : Crystal::Block)
      on_scope_enter(node)
    end

    # :nodoc:
    def end_visit(node : Crystal::Block)
      on_scope_end(node)
    end

    @current_assign : Crystal::ASTNode?

    # :nodoc:
    def visit(node : Crystal::Assign | Crystal::OpAssign | Crystal::MultiAssign)
      @current_assign = node
    end

    # :nodoc:
    def end_visit(node : Crystal::Assign | Crystal::OpAssign)
      @current_scope.try &.assign_variable(node.target)
      @current_assign = nil
    end

    # :nodoc:
    def end_visit(node : Crystal::MultiAssign)
      node.targets.each { |target| @current_scope.try &.assign_variable(target) }
      @current_assign = nil
    end

    # :nodoc:
    def visit(node : Crystal::Arg)
      @current_scope.try &.add_variable Crystal::Var.new(node.name).at(node.location)
    end

    # :nodoc:
    def visit(node : Crystal::Var)
      return unless scope = @current_scope

      if !scope.arg?(node) && (variable = scope.find_variable node.name)
        reference = variable.reference node, scope

        if @current_assign.is_a?(Crystal::OpAssign) || !reference.target_of?(@current_assign)
          variable.reference_assignments!
        end
      else
        scope.add_variable(node)
      end
    end

    # :nodoc:
    def visit(node : Crystal::MacroLiteral)
      MacroLiteralVarVisitor.new(node).vars.each { |var| visit(var) }
    end
  end

  private class MacroLiteralVarVisitor < Crystal::Visitor
    getter vars = [] of Crystal::Var

    def initialize(literal)
      Crystal::Parser.new(literal.value).parse.accept self
    rescue
      nil
    end

    def visit(node : Crystal::ASTNode)
      true
    end

    def visit(node : Crystal::Var)
      vars << node
    end

    def visit(node : Crystal::Call)
      vars << Crystal::Var.new(node.name).at(node.location)
    end
  end
end
