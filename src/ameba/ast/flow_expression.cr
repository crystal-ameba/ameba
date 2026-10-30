require "./util"

module Ameba::AST
  # Represents a flow expression in Crystal code.
  # For example:
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
    include Util

    # Is true only if some of the nodes parents is a loop.
    getter? in_loop : Bool

    # The actual node of the flow expression.
    getter node : Crystal::ASTNode

    delegate location, end_location, to_s,
      to: @node

    # Creates a new flow expression.
    #
    # ```
    # FlowExpression.new(node, parent_node)
    # ```
    def initialize(@node, @in_loop)
    end

    # Returns nodes which can't be reached because of a flow command inside.
    # For example:
    #
    # ```
    # def foobar
    #   a = 3
    #   return 42
    #   a + 1 # => unreachable node
    # end
    # ```
    getter unreachable_nodes : Array(Crystal::ASTNode) do
      case current_node = node
      when Crystal::Expressions
        expressions = current_node.expressions
        # every expression following the first flow expression is unreachable
        if index = expressions.index { |exp| flow_expression?(exp, in_loop?) }
          expressions[(index + 1)..]
        end
      when Crystal::BinaryOp
        if flow_expression?(current_node.left, in_loop?)
          [current_node.right] of Crystal::ASTNode
        end
      end || [] of Crystal::ASTNode
    end
  end
end
