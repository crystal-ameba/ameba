module Ameba::AST
  # Represents a context of the local variable visibility.
  # This is where the local variables belong to.
  class Scope
    # List of all assigned variables in the current scope.
    getter targets = [] of Crystal::ASTNode

    # List of all references in the current scope.
    getter references = [] of Crystal::ASTNode

    getter referenced_targets = [] of Crystal::ASTNode

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

    def captured_by_block?(var, scope = self)
      return variable_used?(var) if scope.node.is_a?(Crystal::Block)

      scope.inner_scopes.each do |inner_scope|
        return true if captured_by_block?(var, inner_scope)
      end

      false
    end

    def variable_used?(var)
      targets.any? { |t| t.is_a?(Crystal::Var) && t.name == var.name } ||
        references.any? { |r| r.is_a?(Crystal::Var) && r.name == var.name }
    end

    # Returns true if the target is referenced in the current scope.
    #
    # ```
    # scope = Scope.new(node, scope)
    # scope.referenced?(target)
    # ```
    def referenced?(target)
      referenced_targets.any? { |t| t.location == target.location }
    end

    # :nodoc:
    private class AssignVarVisitor < Crystal::Visitor
      def initialize(@scope : Scope)
      end

      def visit(node : Crystal::ASTNode)
        true
      end

      def visit(node : Crystal::Assign)
        node.value.accept self

        false
      end

      def visit(node : Crystal::OpAssign)
        true
      end

      def visit(node : Crystal::MultiAssign)
        node.values.each &.accept self

        false
      end

      def end_visit(node : Crystal::Assign | Crystal::OpAssign)
        @scope.targets << node.target
      end

      def end_visit(node : Crystal::MultiAssign)
        node.targets.each { |target| @scope.targets << target }
      end

      def visit(node : Crystal::Var)
        @scope.references << node

        if target = find_ref_target node
          @scope.referenced_targets << target
        end

        false
      end

      private def find_ref_target(var)
        @scope.targets.reverse.find do |target|
          target.is_a?(Crystal::Var) && target.name == var.name
        end
      end
    end
  end
end
