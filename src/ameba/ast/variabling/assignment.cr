require "./reference"
require "./variable"

module Ameba::AST
  # Represents the assignment to the variable.
  # Holds the assign node and the variable.
  class Assignment
    # The actual assignment node.
    getter node : Crystal::ASTNode

    # Variable of this assignment.
    getter variable : Variable

    # A scope assignment belongs to
    getter scope : Scope

    delegate location, end_location, to_s,
      to: @node

    # Creates a new assignment.
    #
    # ```
    # Assignment.new(node, variable, scope)
    # ```
    def initialize(@node, @variable, @scope)
    end

    # Returns `true` if the variable is referenced within an inner scope
    # (i.e. a block) located before this assignment, since such scope might
    # be invoked at any later point (i.e. as a stored callback), thus reading
    # the assigned value.
    #
    # NOTE: The inner scopes located after the assignment are taken into account
    #       by the liveness analysis, as reading the variable at their location.
    def referenced_in_preceding_inner_scope? : Bool
      return true unless assign_location = location

      variable.references.any? do |ref|
        next false unless ref.scope.nested_in?(scope)
        next true unless ref_location = ref.scope.location

        ref_location < assign_location
      end
    end

    # Returns `true` if the address of the variable is taken (i.e. via `pointerof`)
    # before this assignment, since the assigned value might be then read
    # through the pointer at any later point.
    def address_taken_before? : Bool
      return true unless assign_location = location

      variable.references.any? do |ref|
        next false unless ref.address_taken?
        next true unless ref_location = ref.location

        ref_location < assign_location
      end
    end

    # Returns `true` if this assignment is an op assign, `false` if not.
    # For example, this is an op assign:
    #
    # ```
    # a ||= 1
    # ```
    def op_assign?
      node.is_a?(Crystal::OpAssign)
    end

    # Returns the target node of the variable in this assignment.
    def target_node
      case assign = node
      when Crystal::UninitializedVar          then assign.var
      when Crystal::Out                       then assign.exp
      when Crystal::Assign, Crystal::OpAssign then assign.target
      when Crystal::MultiAssign
        assign.targets.each do |target|
          if var = Util.assigned_var(target)
            return var if var.name == variable.name
          end
        end
        node
      else
        node
      end
    end
  end
end
