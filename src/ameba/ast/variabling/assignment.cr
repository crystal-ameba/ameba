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
    getter branch : Branch?

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
      if scope_node = scope.try(&.node)
        @branch = Branch.of(@node, scope_node)
      end
    end
  end
end
