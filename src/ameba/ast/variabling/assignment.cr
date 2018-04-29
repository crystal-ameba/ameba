require "./reference"
require "./variable"

module Ameba::AST
  # Represents the assignment to the variable.
  # Holds the assign node and the variable.
  class Assignment
    property? referenced = false

    # The actual assignment node.
    getter node

    delegate location, to: @node
    delegate to_s, to: @node

    # Creates a new assignment.
    #
    # ```
    # Assignment.new(node, variable)
    # ```
    #
    def initialize(@node : Crystal::ASTNode, @variable : Variable)
    end
  end
end
