require "../../../spec_helper"

module Ameba::AST
  describe Assignment do
    node = Crystal::NilLiteral.new
    variable = Variable.new(Crystal::Var.new("foo"))

    describe "#initialize" do
      it "creates a new assignment with node and var" do
        assignment = Assignment.new(node, variable)
        assignment.node.should_not be_nil
      end
    end

    describe "#reference=" do
      it "creates a new reference" do
        assignment = Assignment.new(node, variable)
        assignment.referenced = true
        assignment.referenced?.should be_true
      end
    end

    describe "delegation" do
      it "delegates location" do
        assignment = Assignment.new(node, variable)
        assignment.location.should eq node.location
      end

      it "delegates to_s" do
        assignment = Assignment.new(node, variable)
        assignment.to_s.should eq node.to_s
      end
    end
  end
end
