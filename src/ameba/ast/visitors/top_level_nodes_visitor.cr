module Ameba::AST
  # AST Visitor that visits certain nodes at a top level, which
  # can characterize the source (i.e. require statements, modules etc.)
  class TopLevelNodesVisitor < Crystal::Visitor
    getter require_nodes = [] of Crystal::Require

    # Creates a new instance of visitor
    def initialize(@scope : Crystal::ASTNode)
      @scope.accept(self)
    end

    # :nodoc:
    def visit(node : Crystal::Require)
      require_nodes << node
    end

    # If a top level node is Crystal::Expressions traverse the children.
    def visit(node : Crystal::Expressions)
      true
    end

    # A general visit method for rest of the nodes.
    # Returns false meaning all child nodes will not be traversed.
    def visit(node : Crystal::ASTNode)
      false
    end
  end
end
