module Ameba::AST
  # Represents a context of the local variable visibility.
  # This is where the local variables belong to.
  # Holds list of all assignments in this scope, link the parent
  # scope, AST node and a assign reference table.
  class Scope
    # List of all assigns in the current scope
    getter assigns = [] of Crystal::Assign

    # Assign to reference table. Each assign may have multiple
    # referenced variables.
    getter assign_ref_table = {} of Crystal::Assign => Array(Crystal::Var)

    # Link to the parent scope
    getter parent : Scope?

    # The actual AST node that represents a current scope.
    getter node : Crystal::ASTNode

    # Creates a new scope. Accepts the AST node and a parent scope.
    #
    # ```
    # scope = Scope.new(class_node, nil)
    # ```
    def initialize(@node, @parent = nil)
      @node.accept VariableVisitor.new(self)
    end

    # Returns true if assignment is referenced in the current scope.
    #
    # ```
    # scope = Scope.new(node, scope)
    # scope.references?(assign)
    # ```
    def references?(assign)
      assign_ref_table.has_key?(assign)
    end

    # :nodoc:
    private class VariableVisitor < Crystal::Visitor
      def initialize(@scope : Scope)
      end

      def visit(node : Crystal::ASTNode)
        true
      end

      def visit(node : Crystal::Assign)
        node.value.accept self

        false
      end

      def end_visit(node : Crystal::Assign)
        @scope.assigns << node
      end

      def visit(node : Crystal::Var)
        @scope.assigns
              .select { |a| (t = a.target) && t.is_a?(Crystal::Var) && t.name == node.name }
              .each do |assign|
          (@scope.assign_ref_table[assign] ||= Array(Crystal::Var).new) << node
        end

        false
      end
    end
  end
end
