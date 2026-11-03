module Ameba::AST
  # A class that utilizes a logic to traverse AST nodes and
  # fire a source test callback if a redundant `Crystal::ControlExpression`
  # is reached.
  #
  # The callback gets told whether the control expression
  # is an operand of a binary or ternary operator.
  class RedundantControlExpressionVisitor
    # A corresponding rule that uses this visitor.
    getter rule : Rule::Base

    # A source that needs to be traversed.
    getter source : Source

    # A node to run traversal on.
    getter node : Crystal::ASTNode

    def initialize(@rule, @source, @node)
      traverse_node(node)
    end

    private def traverse_control_expression(node, operand)
      @rule.test(@source, node, self, operand)
    end

    private def traverse_node(node, *, operand = false)
      case node
      when Crystal::ControlExpression     then traverse_control_expression(node, operand)
      when Crystal::Expressions           then traverse_expressions(node)
      when Crystal::If, Crystal::Unless   then traverse_condition(node)
      when Crystal::Case, Crystal::Select then traverse_case(node)
      when Crystal::BinaryOp              then traverse_binary_op(node)
      when Crystal::ExceptionHandler      then traverse_exception_handler(node)
      end
    end

    private def traverse_expressions(node)
      traverse_node(node.expressions.last?)
    end

    private def traverse_condition(node)
      operand = node.is_a?(Crystal::If) && node.ternary?

      traverse_node(node.then, operand: operand)
      traverse_node(node.else, operand: operand)
    end

    private def traverse_case(node)
      node.whens.each do |when_node|
        traverse_node(when_node.body)
      end
      traverse_node(node.else)
    end

    private def traverse_binary_op(node)
      traverse_node(node.right, operand: true)
    end

    private def traverse_exception_handler(node)
      # The value of the handler comes from its `else` branch, if there is any,
      # which a control expression in the body prevents from being executed.
      traverse_node(node.body) unless node.else
      traverse_node(node.else)

      node.rescues.try &.each do |rescue_node|
        traverse_node(rescue_node.body)
      end
    end
  end
end
