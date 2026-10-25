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

    delegate location, to_s,
      to: @node

    # Creates a new assignment.
    #
    # ```
    # Assignment.new(node, variable, scope)
    # ```
    def initialize(@node, @variable, @scope)
    end

    # Returns the end location of the assignment. In case of a `rescue`
    # it's the end of its variable name (i.e. `rescue ex`), rather than
    # the end of its body.
    def end_location : Crystal::Location?
      case node = @node
      when Crystal::Rescue
        return unless name = node.name

        Util.rescue_name_location(node)
          .try(&.adjust(column_number: name.size - 1))
      else
        node.end_location
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
      when Crystal::Assign, Crystal::OpAssign then assign.target
      when Crystal::MultiAssign
        assign.targets.find(node) do |target|
          target.is_a?(Crystal::Var) && target.name == variable.name
        end
      else
        node
      end
    end
  end
end
