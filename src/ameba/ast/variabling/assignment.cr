require "./reference"
require "./variable"

module Ameba::AST
  # Represents the assignment to the variable.
  # Holds the assign node and the variable.
  class Assignment
    property? referenced = false

    # The actual assignment node.
    getter node : Crystal::ASTNode

    # Variable of this assignment.
    getter variable : Variable

    # Branch of this assignment.
    getter branch : Branch?

    # A scope assignment belongs to
    getter scope : Scope

    delegate to_s, to: @node
    delegate location, to: @node
    delegate end_location, to: @node

    # Creates a new assignment.
    #
    # ```
    # Assignment.new(node, variable, scope)
    # ```
    def initialize(@node, @variable, @scope)
      return unless scope = @variable.scope

      @branch = Branch.of(@node, scope)
      @referenced = true if @variable.special? || referenced_in_loop?
    end

    def referenced_in_loop?
      @variable.referenced? && !!@branch.try(&.in_loop?)
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

    # Returns `true` if this assignment is in a branch, `false` if not.
    # For example, this assignment is in a branch:
    #
    # ```
    # a = 1 if a.nil?
    # ```
    def in_branch?
      !branch.nil?
    end

    # Returns the target node of the variable in this assignment.
    def target_node
      case assign = node
      when Crystal::Assign           then assign.target
      when Crystal::OpAssign         then assign.target
      when Crystal::UninitializedVar then assign.var
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
