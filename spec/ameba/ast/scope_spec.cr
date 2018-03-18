require "../../spec_helper"

module Ameba::AST
  describe Scope do
    describe ".new" do
      source = "a = 2"

      it "assigns outer scope" do
        root = Scope.new as_node(source)
        child = Scope.new as_node(source), root
        child.outer_scope.should_not be_nil
      end

      it "assigns node" do
        scope = Scope.new as_node(source)
        scope.node.should_not be_nil
      end
    end

    describe "#targets" do
      it "returns a list of all targets" do
        scope = Scope.new as_node %(
          foo = 1
          bar = 2
        )
        scope.targets.size.should eq 2
      end

      it "does not count references" do
        scope = Scope.new as_node %(
          foo = 1
          foo
        )
        scope.targets.size.should eq 1
      end
    end

    describe "#referenced?" do
      it "returns true if a target has a reference below" do
        scope = Scope.new as_node %(
          a = 2
          a
        )
        scope.referenced?(scope.targets.first).should be_true
      end

      it "returns false if a target does not have a reference" do
        scope = Scope.new as_node %(
          foo = 2
          bar = 3
        )
        scope.referenced?(scope.targets.first).should be_false
        scope.referenced?(scope.targets.last).should be_false
      end
    end
  end
end
