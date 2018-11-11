require "./base_visitor"

module Ameba::AST
  # AST Visitor that traverses all the flow expressions.
  class FlowExpressionVisitor < BaseVisitor
    @node_stack = Array(Crystal::ASTNode).new
    @flow_expression : FlowExpression?

    def initialize(@rule, @source)
      @source.ast.accept self
    end

    def visit(node)
      @node_stack.push node
    end

    def end_visit(node)
      if @flow_expression.nil?
        @node_stack.pop unless @node_stack.empty?
      else
        @flow_expression = nil
      end
    end

    def visit(node : Crystal::ControlExpression)
      on_flow_expression_start(node)

      true
    end

    def visit(node : Crystal::Call)
      if raise?(node) || exit?(node) || abort?(node)
        on_flow_expression_start(node)
      else
        @node_stack.push node
      end

      true
    end

    private def on_flow_expression_start(node)
      if parent_node = @node_stack.last?
        @flow_expression = FlowExpression.new(node, parent_node)
        @rule.test @source, node, @flow_expression
      end
    end

    private def raise?(node)
      node.name == "raise" && node.args.size == 1 && node.obj.nil?
    end

    private def exit?(node)
      node.name == "exit" && node.args.size <= 1 && node.obj.nil?
    end

    private def abort?(node)
      node.name == "abort" && node.args.size <= 2 && node.obj.nil?
    end
  end
end
