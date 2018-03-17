require "../../spec_helper"

module Ameba::AST
  describe Scope do
    describe ".new" do
      source = "a = 2"

      it "assigns parent scope" do
        root = Scope.new as_node(source)
        child = Scope.new as_node(source), root
        child.parent.should_not be_nil
      end

      it "assigns node" do
        scope = Scope.new as_node(source)
        scope.node.should_not be_nil
      end
    end

    describe "#assigns" do
      it "returns a list of all assigns" do
        scope = Scope.new as_node %(
          foo = 1
          bar = 2
        )
        scope.assigns.size.should eq 2
      end

      it "does not count references" do
        scope = Scope.new as_node %(
          foo = 1
          foo
        )
        scope.assigns.size.should eq 1
      end
    end

    describe "#assign_ref_table" do
      it "may be empty" do
        scope = Scope.new as_node %(
          foo = 1
          bar = 2
        )
        scope.assign_ref_table.empty?.should be_true
      end

      it "is not empty if there are references to assigns" do
        scope = Scope.new as_node %(
          foo = 1
          foo = foo + 1
          foo
        )
        scope.assign_ref_table.empty?.should be_false
        scope.assign_ref_table.size.should eq 2
        scope.assign_ref_table.first[1].size.should eq 2
      end
    end

    describe "#references?" do
      it "returns true if assignment has a reference below" do
        scope = Scope.new as_node %(
          a = 2
          a
        )
        scope.references?(scope.assigns.first).should be_true
      end

      it "returns false if assignment does not have a reference" do
        scope = Scope.new as_node %(
          foo = 2
          bar = 3
        )
        scope.references?(scope.assigns.first).should be_false
        scope.references?(scope.assigns.last).should be_false
      end
    end
  end
end
