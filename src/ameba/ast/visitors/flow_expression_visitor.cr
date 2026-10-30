require "../util"
require "./base_visitor"

module Ameba::AST
  # AST Visitor that traverses all the flow expressions.
  class FlowExpressionVisitor < BaseVisitor
    include Util

    @loop_stack = [] of Crystal::ASTNode

    # Object ids of the already reported unreachable nodes
    @unreachable_node_ids = Set(UInt64).new

    # :nodoc:
    #
    # Called by `Crystal::ASTNode#accept` before `visit` for every node.
    # Returning `false` skips the node entirely (both `visit` and `end_visit`),
    # which keeps `@loop_stack` balanced for the skipped loops and blocks.
    def visit_any(node)
      # skip flow expressions nested within the already reported unreachable code
      !@unreachable_node_ids.includes?(node.object_id)
    end

    # :nodoc:
    def visit(node)
      if flow_expression?(node, in_loop?)
        flow_expression = FlowExpression.new(node, in_loop?)
        flow_expression.unreachable_nodes.each do |unreachable_node|
          @unreachable_node_ids << unreachable_node.object_id
        end
        @rule.test(@source, node, flow_expression)
      end
      true
    end

    # :nodoc:
    def visit(node : Crystal::While | Crystal::Until)
      on_loop_started(node)
      true
    end

    # :nodoc:
    def visit(node : Crystal::Block | Crystal::ProcLiteral)
      on_loop_started(node)
      true
    end

    # :nodoc:
    def end_visit(node : Crystal::While | Crystal::Until)
      on_loop_ended(node)
    end

    # :nodoc:
    def end_visit(node : Crystal::Block | Crystal::ProcLiteral)
      on_loop_ended(node)
    end

    private def on_loop_started(node)
      @loop_stack.push(node)
    end

    private def on_loop_ended(node)
      @loop_stack.pop?
    end

    private def in_loop?
      @loop_stack.present?
    end
  end
end
