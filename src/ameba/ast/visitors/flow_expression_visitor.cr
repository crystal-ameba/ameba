require "./base_visitor"

module Ameba::AST
  # AST Visitor that traverses all the flow expressions.
  class FlowExpressionVisitor < BaseVisitor
    @node_stack = Array(Crystal::ASTNode).new

    def initialize(@rule, @source)
      @source.ast.accept self
    end

    def visit(node)
      @node_stack.push node
    end

    def end_visit(node)
      @node_stack.pop
    end

    def visit(node : Crystal::ControlExpression)
      if parent_node = @node_stack.last?
        flow_expression = FlowExpression.new(node, parent_node)
        @rule.test @source, node, flow_expression
      end

      true
    end

    def end_visit(node : Crystal::ControlExpression)
      #
    end
  end
end
