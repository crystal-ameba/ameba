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

    # Object ids of the expressions placed directly within a class or module body
    @type_body_ids = Set(UInt64).new

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
      in_type_body = @type_body_ids.includes?(node.object_id)

      if flow_expression?(node, in_loop?, in_type_body: in_type_body)
        flow_expression = FlowExpression.new(node, in_loop?, in_type_body)
        flow_expression.unreachable_nodes.each do |unreachable_node|
          @unreachable_node_ids << unreachable_node.object_id
        end
        @rule.test(@source, node, flow_expression)
      end
      true
    end

    # :nodoc:
    def visit(node : Crystal::ClassDef | Crystal::ModuleDef)
      mark_type_body(node.body)
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

    private def mark_type_body(node)
      return unless node.is_a?(Crystal::Expressions)

      @type_body_ids << node.object_id
      node.expressions.each { |exp| mark_type_body(exp) }
    end
  end
end
