require "./reference"
require "./variable"

module Ameba::AST
  # Represents the assignment to the variable.
  # Holds the assign node and the variable.
  class Assignment
    # A list of variable references for this assignment.
    getter references = [] of Reference

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

    # References this assignment meaning the variable
    # is used below the assignment.
    #
    # ```
    # assignment.reference(node)
    # ```
    #
    def reference(node)
      references << Reference.new(node)
    end

    # Returns true if the assignment has any references,
    # false - otherwise.
    #
    # ```
    # assignment.reference(node)
    # assignment.referenced? # => true
    # ```
    #
    def referenced?
      references.any?
    end
  end
end
