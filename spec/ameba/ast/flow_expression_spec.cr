require "../../spec_helper"

module Ameba::AST
  describe FlowExpression do
    describe "#initialize" do
      it "creates a new flow expression" do
        node = as_node("return 22")
        parent_node = as_node("def foo; return 22; end")
        flow_expression = FlowExpression.new node, parent_node
        flow_expression.node.should_not be_nil
        flow_expression.parent_node.should_not be_nil
      end

      describe "#delegation" do
        it "delegates to_s to @node" do
          node = as_node("return 22")
          parent_node = as_node("def foo; return 22; end")
          flow_expression = FlowExpression.new node, parent_node
          flow_expression.to_s.should eq node.to_s
        end

        it "delegates location to @node" do
          node = as_node %(break if true)
          parent_node = as_node("def foo; return 22 if true; end")
          flow_expression = FlowExpression.new node, parent_node
          flow_expression.location.should eq node.location
        end
      end

      describe "#find_unreachable_node" do
        it "returns first unreachable node" do
          nodes = as_nodes %(
            def foobar
              return
              a = 1
              a + 1
            end
          )
          node = nodes.control_expression_nodes.first
          assign_node = nodes.assign_nodes.first
          def_node = nodes.def_nodes.first
          flow_expression = FlowExpression.new node, def_node
          flow_expression.find_unreachable_node.should eq assign_node
        end

        it "returns nil if there is no unreachable node" do
          nodes = as_nodes %(
            def foobar
              a = 1
              return a
            end
          )
          node = nodes.control_expression_nodes.first
          def_node = nodes.def_nodes.first
          flow_expression = FlowExpression.new node, def_node
          flow_expression.find_unreachable_node.should eq nil
        end
      end
    end
  end
end
