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

    delegate location, to: @node
    delegate to_s, to: @node
    delegate scope, to: @variable

    # Creates a new assignment.
    #
    # ```
    # Assignment.new(node, variable)
    # ```
    #
    def initialize(@node, @variable)
      if scope = @variable.scope
        @branch = Branch.of(@node, scope)
        @referenced = true if @variable.special? ||
                              @variable.scope.type_definition? ||
                              referenced_in_loop?
      end
    end

    def referenced_in_loop?
      @variable.referenced? && @branch.try &.in_loop?
    end
  end
end
