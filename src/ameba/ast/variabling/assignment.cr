require "./reference"
require "./variable"

module Ameba::AST
  # Represents the assignment to the variable.
  # Holds the assign node and the variable.
  class Assignment
    property? referenced = false

    # The actual assignment node.
    getter node

    # Variable of this assignment.
    getter variable

    # Branch of this assignment.
    @branch : Branch?

    delegate location, to: @node
    delegate to_s, to: @node
    delegate scope, to: @variable

    # Creates a new assignment.
    #
    # ```
    # Assignment.new(node, variable)
    # ```
    #
    def initialize(@node : Crystal::ASTNode, @variable : Variable)
    end

    # Returns branch of the assignment if there is any or nil.
    # For example, this assignment has branch node:
    #
    # ```
    # def method(a)
    #   if a
    #     a = 3 # assignment in a branch
    #   end
    # end
    # ```
    def branch
      if scope_node = scope.try(&.node)
        @branch ||= Branch.of(@node, scope_node)
      end
    end
  end
end
