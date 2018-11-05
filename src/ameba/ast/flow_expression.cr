module Ameba::AST
  # Represents a flow expression in Crystal code.
  # For example,
  #
  # ```
  # def foobar
  #   a = 3
  #   return 42 # => flow expression
  #   a + 1
  # end
  # ```
  #
  # Flow expression contains an actual node of a control expression and
  # a parent node, which allows easily search through the related statement
  # (i.e. find unreachable code)
  class FlowExpression
    # The actual node of the flow expression.
    getter node : Crystal::ASTNode

    # Parent ast node.
    getter parent_node : Crystal::ASTNode

    delegate to_s, to: @node
    delegate location, to: @node

    # Creates a new flow expression.
    #
    # ```
    # FlowExpression.new(node, parent_node)
    # ```
    def initialize(@node, @parent_node)
    end

    # Returns first node which can't be reached because of a flow expression.
    # For example:
    #
    # ```
    # def foobar
    #   a = 1
    #   return 42
    #
    #   a + 2 # => unreachable assign node
    # end
    # ```
    #
    def find_unreachable_node
      UnreachableNodeVisitor.new(node, parent_node)
        .tap(&.accept parent_node)
        .unreachable_nodes
        .first?
    end

    # :nodoc:
    private class UnreachableNodeVisitor < Crystal::Visitor
      getter unreachable_nodes = Array(Crystal::ASTNode).new
      @after_control_flow_node = false
      @branch : AST::Branch?

      def initialize(@node : Crystal::ASTNode, parent_node)
        @branch = Branch.of(@node, parent_node)
      end

      def visit(node : Crystal::ASTNode)
        if node.class == @node.class &&
           node.location == @node.location
          @after_control_flow_node = true
          return false
        end

        if @after_control_flow_node && !node.nop? && @branch.nil?
          @unreachable_nodes << node
          return false
        end

        true
      end
    end
  end
end
