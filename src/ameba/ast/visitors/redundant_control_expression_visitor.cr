module Ameba::AST
  # A class that utilizes a logic to traverse AST nodes and
  # fire a source test callback if a redundant `Crystal::ControlExpression`
  # is reached.
  class RedundantControlExpressionVisitor
    # A corresponding rule that uses this visitor.
    getter rule : Rule::Base

    # A source that needs to be traversed.
    getter source : Source

    # A node to run traversal on.
    getter node : Crystal::ASTNode

    # Whether the reached control expression is an operand of a binary operator.
    getter? operand = false

    def initialize(@rule, @source, @node)
      traverse_node(node)
    end

    private def traverse_control_expression(node)
      @rule.test(@source, node, self)
    end

    private def traverse_node(node)
      case node
      when Crystal::ControlExpression     then traverse_control_expression(node)
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
      traverse_node(node.then)
      traverse_node(node.else)
    end

    private def traverse_case(node)
      node.whens.each do |when_node|
        traverse_node(when_node.body)
      end
      traverse_node(node.else)
    end

    private def traverse_binary_op(node)
      @operand = node.right.is_a?(Crystal::ControlExpression)
      traverse_node(node.right)
      @operand = false
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
