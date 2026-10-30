require "../util"
require "./base_visitor"

module Ameba::AST
  # AST Visitor that traverses all the flow expressions.
  class FlowExpressionVisitor < BaseVisitor
    include Util

    # Number of the loops, blocks and procs enclosing the currently visited node
    @loop_depth = 0

    # Object ids of the already reported unreachable nodes
    @unreachable_node_ids = Set(UInt64).new

    # :nodoc:
    #
    # Called by `Crystal::ASTNode#accept` before `visit` for every node.
    # Returning `false` skips the node entirely (both `visit` and `end_visit`),
    # which keeps `@loop_depth` balanced for the skipped loops and blocks.
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
    def visit(node : Crystal::While | Crystal::Until | Crystal::Block | Crystal::ProcLiteral)
      @loop_depth += 1
      true
    end

    # :nodoc:
    def end_visit(node : Crystal::While | Crystal::Until | Crystal::Block | Crystal::ProcLiteral)
      @loop_depth -= 1
    end

    # Returns `true` if `break` / `next` within the currently visited node
    # are flow commands, i.e. it's nested within a loop, block or proc.
    private def in_loop?
      @loop_depth.positive?
    end
  end
end
