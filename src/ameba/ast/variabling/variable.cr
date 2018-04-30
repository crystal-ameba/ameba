module Ameba::AST
  # Represents the existence of the local variable.
  # Holds the var node and variable assigments.
  class Variable
    # List of the assigments of this variable.
    getter assignments = [] of Assignment

    # List of the references of this variable.
    getter references = [] of Reference

    # The actual var node.
    getter node : Crystal::Var

    # Scope of this variable.
    getter scope : Scope?

    delegate location, to: @node
    delegate name, to: @node
    delegate to_s, to: @node

    # Creates a new variable(in the scope).
    #
    # ```
    # Variable.new(node, scope)
    # ```
    #
    def initialize(@node, @scope = nil)
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
    #
    def assign(node)
      assignments << Assignment.new(node, self)
    end

    # Returns true if variable has any reference.
    #
    # ```
    # variable = Variable.new(node, scope)
    # variable.reference(var_node)
    # variable.referenced? # => true
    # ```
    def referenced?
      references.any?
    end

    # References the existed assignments.
    #
    # ```
    # variable = Variable.new(node, scope)
    # variable.assign(assign_node)
    # variable.reference(var_node)
    # ```
    #
    def reference(node : Crystal::Var)
      references << Reference.new(node)
      consumed_branches = Set(Branch).new

      assignments.reverse_each do |assignment|
        next if consumed_branches.includes?(assignment.branch)
        assignment.referenced = true

        break unless assignment.branch
        consumed_branches << assignment.branch.not_nil!
      end
    end

    # Returns true if the current assignment is captured (used in)
    # by the `Crystal::Block`. For example this variable is captured
    # by block:
    #
    # ```
    # a = 1
    # 3.times { |i| a = a + i }
    # ```
    #
    def captured_by_block?(scope = @scope)
      return false unless scope
      return scope.find_variable(name) if scope.node.is_a?(Crystal::Block)

      scope.inner_scopes.each do |inner_scope|
        return true if captured_by_block?(inner_scope)
      end

      false
    end

    # Returns true if the variable is a target (on the left) of the assignment,
    # false otherwise.
    def target_of?(assign)
      case assign
      when Crystal::Assign      then eql?(assign.target)
      when Crystal::OpAssign    then eql?(assign.target)
      when Crystal::MultiAssign then assign.targets.any? { |t| eql?(t) }
      else
        false
      end
    end

    # Returns true if the `node` represents exactly
    # the same Crystal node as `@node`.
    def eql?(node)
      node.is_a?(Crystal::Var) &&
        node.name == @node.name &&
        node.location == @node.location
    end
  end
end
