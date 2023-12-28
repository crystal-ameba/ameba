module Ameba::AST
  # Represents the existence of the local variable.
  # Holds the var node and variable assignments.
  class Variable
    # List of the assignments of this variable.
    getter assignments = [] of Assignment

    # List of the references of this variable.
    getter references = [] of Reference

    # The actual var node.
    getter node : Crystal::Var

    # Scope of this variable.
    getter scope : Scope

    # Node of the first assignment which can be available before any reference.
    getter assign_before_reference : Crystal::ASTNode?

    delegate location, end_location, name, to_s,
      to: @node

    # Creates a new variable(in the scope).
    #
    # ```
    # Variable.new(node, scope)
    # ```
    def initialize(@node, @scope)
    end

    # Returns `true` if it is a special variable, i.e `$?`.
    def special?
      @node.special_var?
    end

    # Assigns the variable (creates a new assignment).
    # Variable may have multiple assignments.
    #
    # ```
    # variable = Variable.new(node, scope)
    # variable.assign(node1)
    # variable.assign(node2)
    # variable.assignment.size # => 2
    # ```
    def assign(node, scope)
      assignments << Assignment.new(node, self, scope)

      update_assign_reference!
    end

    # Returns `true` if variable has any reference.
    #
    # ```
    # variable = Variable.new(node, scope)
    # variable.reference(var_node, some_scope)
    # variable.referenced? # => true
    # ```
    def referenced?
      !references.empty?
    end

    # Creates a reference to this variable in some scope.
    #
    # ```
    # variable = Variable.new(node, scope)
    # variable.reference(var_node, some_scope)
    # ```
    def reference(node : Crystal::Var, scope : Scope)
      Reference.new(node, scope).tap do |reference|
        references << reference
        scope.references << reference
      end
    end

    # :ditto:
    def reference(scope : Scope)
      reference(node, scope)
    end

    # Reference variable's assignments.
    #
    # ```
    # variable = Variable.new(node, scope)
    # variable.assign(assign_node)
    # variable.reference_assignments!
    # ```
    def reference_assignments!
      consumed_branches = Set(Branch).new

      assignments.reverse_each do |assignment|
        next if assignment.branch.in?(consumed_branches)
        assignment.referenced = true

        break unless branch = assignment.branch
        consumed_branches << branch
      end
    end

    # Returns `true` if the current var is referenced in
    # in the block. For example this variable is captured
    # by block:
    #
    # ```
    # a = 1
    # 3.times { |i| a = a + i }
    # ```
    #
    # And this variable is not captured by block.
    #
    # ```
    # i = 1
    # 3.times { |i| i + 1 }
    # ```
    def captured_by_block?(scope = @scope)
      scope.inner_scopes.each do |inner_scope|
        return true if inner_scope.block? &&
                       inner_scope.references?(self, check_inner_scopes: false)
        return true if captured_by_block?(inner_scope)
      end

      false
    end

    # Returns `true` if current variable potentially referenced in a macro,
    # `false` if not.
    def used_in_macro?(scope = @scope)
      scope.inner_scopes.each do |inner_scope|
        return true if MacroReferenceFinder.new(inner_scope.node, node.name).references?
      end
      return true if MacroReferenceFinder.new(scope.node, node.name).references?
      return true if (outer_scope = scope.outer_scope) && used_in_macro?(outer_scope)

      false
    end

    # Returns `true` if the variable is a target (on the left) of the assignment,
    # `false` otherwise.
    def target_of?(assign)
      case assign
      when Crystal::Assign           then eql?(assign.target)
      when Crystal::OpAssign         then eql?(assign.target)
      when Crystal::MultiAssign      then assign.targets.any? { |target| eql?(target) }
      when Crystal::UninitializedVar then eql?(assign.var)
      else
        false
      end
    end

    # Returns `true` if the name starts with '_', `false` if not.
    def ignored?
      name.starts_with? '_'
    end

    # Returns `true` if the `node` represents exactly
    # the same Crystal node as `@node`.
    def eql?(node)
      node.is_a?(Crystal::Var) &&
        node.name == @node.name &&
        node.location == @node.location
    end

    # Returns `true` if the variable is declared before the `node`.
    def declared_before?(node)
      var_location, node_location = location, node.location

      return unless var_location && node_location

      (var_location.line_number < node_location.line_number) ||
        (var_location.line_number == node_location.line_number &&
          var_location.column_number < node_location.column_number)
    end

    private class MacroReferenceFinder < Crystal::Visitor
      property? references = false

      def initialize(node, @reference : String)
        node.accept self
      end

      @[AlwaysInline]
      private def includes_reference?(val)
        val.to_s.includes?(@reference)
      end

      def visit(node : Crystal::MacroLiteral)
        !(@references ||= includes_reference?(node.value))
      end

      def visit(node : Crystal::MacroExpression)
        !(@references ||= includes_reference?(node.exp))
      end

      def visit(node : Crystal::MacroFor)
        !(@references ||= includes_reference?(node.exp) ||
                          includes_reference?(node.body))
      end

      def visit(node : Crystal::MacroIf)
        !(@references ||= includes_reference?(node.cond) ||
                          includes_reference?(node.then) ||
                          includes_reference?(node.else))
      end

      def visit(node : Crystal::ASTNode)
        true
      end
    end

    private def update_assign_reference!
      return if @assign_before_reference
      return if references.size > assignments.size
      return if assignments.any?(&.op_assign?)

      @assign_before_reference = assignments
        .find(&.in_branch?.!)
        .try(&.node)
    end
  end
end
