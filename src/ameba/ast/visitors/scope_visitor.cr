require "./base_visitor"

module Ameba::AST
  # AST Visitor that traverses the source and constructs scopes.
  class ScopeVisitor < BaseVisitor
    @current_scope : Scope

    def initialize(@rule, @source)
      @current_scope = Scope.new(@source.ast) # top level scope
      @source.ast.accept self
    end

    private def on_scope_enter(node)
      @current_scope = Scope.new(node, @current_scope)
    end

    private def on_scope_end(node)
      @rule.test @source, node, @current_scope

      # go up, if this is not a top level scope
      if outer_scope = @current_scope.outer_scope
        @current_scope = outer_scope
      end
    end

    # :nodoc:
    def end_visit(node : Crystal::ASTNode)
      on_scope_end(node) if @current_scope.eql?(node)
    end

    # :nodoc:
    def visit(node : Crystal::ClassDef)
      on_scope_enter(node)
    end

    # :nodoc:
    def visit(node : Crystal::ModuleDef)
      on_scope_enter(node)
    end

    # :nodoc:
    def visit(node : Crystal::LibDef)
      on_scope_enter(node)
    end

    # :nodoc:
    def visit(node : Crystal::FunDef)
      on_scope_enter(node)
    end

    # :nodoc:
    def visit(node : Crystal::TypeDef)
      on_scope_enter(node)
    end

    # :nodoc:
    def visit(node : Crystal::CStructOrUnionDef)
      on_scope_enter(node)
    end

    # :nodoc:
    def visit(node : Crystal::Def)
      node.name == "->" || on_scope_enter(node)
    end

    # :nodoc:
    def visit(node : Crystal::ProcLiteral)
      on_scope_enter(node)
    end

    # :nodoc:
    def visit(node : Crystal::Block)
      on_scope_enter(node)
    end

    @current_assign : Crystal::ASTNode?

    # :nodoc:
    def visit(node : Crystal::Assign | Crystal::OpAssign | Crystal::MultiAssign)
      @current_assign = node
    end

    # :nodoc:
    def end_visit(node : Crystal::Assign | Crystal::OpAssign)
      @current_scope.assign_variable(node.target)
      @current_assign = nil
    end

    # :nodoc:
    def end_visit(node : Crystal::MultiAssign)
      node.targets.each { |target| @current_scope.assign_variable(target) }
      @current_assign = nil
    end

    # :nodoc:
    def visit(node : Crystal::Arg)
      @current_scope.add_variable Crystal::Var.new(node.name).at(node.location)
    end

    # :nodoc:
    def visit(node : Crystal::Var)
      if !@current_scope.arg?(node) && (variable = @current_scope.find_variable node.name)
        reference = variable.reference node, @current_scope

        if @current_assign.is_a?(Crystal::OpAssign) || !reference.target_of?(@current_assign)
          variable.reference_assignments!
        end
      else
        @current_scope.add_variable(node)
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
