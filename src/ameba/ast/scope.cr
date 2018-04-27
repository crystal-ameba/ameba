require "./variabling/*"

module Ameba::AST
  # Represents a context of the local variable visibility.
  # This is where the local variables belong to.
  class Scope
    # Link to local variables
    getter variables = [] of Variable

    # Link to the outer scope
    getter outer_scope : Scope?

    # List of inner scopes
    getter inner_scopes = [] of Scope

    # The actual AST node that represents a current scope.
    getter node : Crystal::ASTNode

    # Creates a new scope. Accepts the AST node and the outer scope.
    #
    # ```
    # scope = Scope.new(class_node, nil)
    # ```
    def initialize(@node, @outer_scope = nil)
      @outer_scope.try &.inner_scopes.<<(self)
      @node.accept AssignVarVisitor.new(self)
    end

    # Creates a new variable in the current scope.
    #
    # ```
    # scope = Scope.new(class_node, nil)
    # scope.add_variable(var_node)
    # ```
    def add_variable(node)
      variables << Variable.new(node, self)
    end

    # Returns variable by its name or nil if it does not exist.
    #
    # ```
    # scope = Scope.new(class_node, nil)
    # scope.find_variable("foo")
    # ```
    def find_variable(name : String)
      variables.find { |v| v.name == name }
    end

    # Creates a new assignment for the variable.
    def assign_variable(node)
      node.is_a?(Crystal::Var) && find_variable(node.name).try &.assign(node)
    end

    # :nodoc:
    private class AssignVarVisitor < Crystal::Visitor
      @current_assign : Crystal::ASTNode?

      def initialize(@scope : Scope)
      end

      def visit(node : Crystal::ASTNode)
        true
      end

      def visit(node : Crystal::Assign | Crystal::OpAssign | Crystal::MultiAssign)
        @current_assign = node
      end

      def end_visit(node : Crystal::Assign | Crystal::OpAssign)
        @scope.assign_variable(node.target)
        @current_assign = nil
      end

      def end_visit(node : Crystal::MultiAssign)
        node.targets.each { |target| @scope.assign_variable(target) }
        @current_assign = nil
      end

      def visit(node : Crystal::Var)
        if variable = @scope.find_variable(node.name)
          (@current_assign.is_a? Crystal::OpAssign ||
            !Reference.new(node).target_of? @current_assign) &&
            variable.reference_assignments(node)
        else
          @scope.add_variable(node)
        end
      end
    end
  end
end
