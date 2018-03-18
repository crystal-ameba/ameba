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

    # The actual AST node that represents a current scope.
    getter node : Crystal::ASTNode

    # Creates a new scope. Accepts the AST node and the outer scope.
    #
    # ```
    # scope = Scope.new(class_node, nil)
    # ```
    def initialize(@node, @outer_scope = nil)
      @node.accept AssignVarVisitor.new(self)
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
