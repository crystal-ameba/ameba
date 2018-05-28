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

    # Returns true if this assignment is an op assign, false if not.
    # For example, this is an op assign:
    #
    # ```
    # a ||= 1
    # ```
    def op_assign?
      node.is_a? Crystal::OpAssign
    end

    # Returns true if this assignment is in a branch, false if not.
    # For example, this assignment is in a branch:
    #
    # ```
    # a = 1 if a.nil?
    # ```
    def in_branch?
      !branch.nil?
    end

    # Returns the location of the current variable in the assignment.
    def location
      case assign = node
      when Crystal::Assign           then assign.target.location
      when Crystal::OpAssign         then assign.target.location
      when Crystal::UninitializedVar then assign.var.location
      when Crystal::MultiAssign
        assign.targets.find do |target|
          target.is_a?(Crystal::Var) && target.name == variable.name
        end.try &.location
      else
        node.location
      end
    end
  end
end
