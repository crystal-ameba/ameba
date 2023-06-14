require "./util"

module Ameba::AST
  # A generic entity to represent a branchable Crystal node.
  # For example, `Crystal::If`, `Crystal::Unless`, `Crystal::While`
  # are branchables.
  #
  # ```
  # while a > 100 # Branchable A
  #   if b > 2    # Branchable B
  #     a += 1
  #   end
  # end
  # ```
  class Branchable
    include Util

    # Parent branchable (if any)
    getter parent : Branchable?

    # Array of branches
    getter branches = [] of Crystal::ASTNode

    # The actual Crystal node
    getter node : Crystal::ASTNode

    delegate to_s, to: @node
    delegate location, to: @node
    delegate end_location, to: @node

    # Creates a new branchable
    #
    # ```
    # Branchable.new(node, parent_branchable)
    # ```
    def initialize(@node, @parent = nil)
    end

    # Returns `true` if this node or one of the parent branchables is a loop,
    # `false` otherwise.
    def loop?
      loop?(node) || !!parent.try(&.loop?)
    end
  end
end
