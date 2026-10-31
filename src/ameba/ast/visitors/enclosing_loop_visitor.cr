module Ameba::AST
  # AST Visitor that finds the loops (`while` / `until`) enclosing the given node.
  class EnclosingLoopVisitor < Crystal::Visitor
    # The loops enclosing the target node, from the outermost one
    getter loops = [] of Crystal::While | Crystal::Until

    # Creates a new visitor of the *node*, finding the loops enclosing the *target*
    def initialize(node : Crystal::ASTNode, @target : Crystal::ASTNode)
      node.accept(self)
    end

    # :nodoc:
    def visit(node : Crystal::While | Crystal::Until)
      return false unless encloses?(node)

      @loops << node unless node.same?(@target)
      true
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode)
      encloses?(node)
    end

    # Returns `true` if the *node* might enclose the target node.
    private def encloses?(node) : Bool
      return true unless (location = node.location) && (end_location = node.end_location)
      return true unless (target_location = @target.location) && (target_end_location = @target.end_location)

      location <= target_location && target_end_location <= end_location
    end
  end
end
