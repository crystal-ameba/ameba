require "../../../spec_helper"

module Ameba::AST
  describe Assignment do
    node = Crystal::NilLiteral.new
    scope = Scope.new as_node "foo = 1"
    variable = Variable.new(Crystal::Var.new("foo"), scope)

    describe "#initialize" do
      it "creates a new assignment with node and var" do
        assignment = Assignment.new(node, variable, scope)
        assignment.node.should_not be_nil
      end
    end

    describe "delegation" do
      it "delegates locations" do
        assignment = Assignment.new(node, variable, scope)
        assignment.location.should eq node.location
        assignment.end_location.should eq node.end_location
      end

      it "delegates to_s" do
        assignment = Assignment.new(node, variable, scope)
        assignment.to_s.should eq node.to_s
      end

      it "delegates scope" do
        assignment = Assignment.new(node, variable, scope)
        assignment.scope.should eq variable.scope
      end
    end
  end
end
