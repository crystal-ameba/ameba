require "../../spec_helper"

module Ameba::AST
  describe FlowExpression do
    describe "#initialize" do
      it "creates a new flow expression" do
        node = as_node("return 22")
        flow_expression = FlowExpression.new node, false
        flow_expression.node.should_not be_nil
        flow_expression.in_loop?.should be_false
      end

      describe "#delegation" do
        it "delegates to_s to @node" do
          node = as_node("return 22")
          flow_expression = FlowExpression.new node, false
          flow_expression.to_s.should eq node.to_s
        end

        it "delegates locations to @node" do
          node = as_node("break if true")
          flow_expression = FlowExpression.new node, false
          flow_expression.location.should eq node.location
          flow_expression.end_location.should eq node.end_location
        end
      end

      describe "#unreachable_nodes" do
        it "returns unreachable nodes" do
          nodes = as_nodes <<-CRYSTAL
            def foobar
              return
              a = 1
              a = 2
            end
            CRYSTAL
          node = nodes.expressions_nodes.first
          flow_expression = FlowExpression.new node, false
          flow_expression.unreachable_nodes.should eq nodes.assign_nodes
        end

        it "returns nil if there is no unreachable node after loop" do
          nodes = as_nodes <<-CRYSTAL
            def run
              idx = items.size - 1
              while 0 <= idx
                return
              end

              puts "foo"
            end
            CRYSTAL
          node = nodes.expressions_nodes.first
          flow_expression = FlowExpression.new node, false
          flow_expression.unreachable_nodes.empty?.should eq true
        end

        it "returns nil if there is no unreachable node" do
          nodes = as_nodes <<-CRYSTAL
            def foobar
              a = 1
              return a
            end
            CRYSTAL
          node = nodes.expressions_nodes.first
          flow_expression = FlowExpression.new node, false
          flow_expression.unreachable_nodes.empty?.should eq true
        end
      end
    end
  end
end
