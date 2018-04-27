require "../../spec_helper"

module Ameba::AST
  describe Scope do
    describe "#initialize" do
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
  end

  describe "#add_variable" do
    it "adds a new variable to the scope" do
      scope = Scope.new as_node("")
      scope.add_variable(Crystal::Var.new "foo")
      scope.variables.any?.should be_true
    end
  end

  describe "#find_variable" do
    it "returns the variable in the scope by name" do
      scope = Scope.new as_node("foo = 1")
      scope.find_variable("foo").should_not be_nil
    end

    it "returns nil if variable not exist in this scope" do
      scope = Scope.new as_node("foo = 1")
      scope.find_variable("bar").should be_nil
    end
  end

  describe "#assign_variable" do
    it "creates a new assignment" do
      scope = Scope.new as_node("foo = 1")
      scope.find_variable("foo").not_nil!.assignments.size.should eq 1
      scope.assign_variable(Crystal::Var.new "foo")
      scope.find_variable("foo").not_nil!.assignments.size.should eq 2
    end

    it "does not create the assignment if variable is wrong" do
      scope = Scope.new as_node("foo = 1")
      scope.assign_variable(Crystal::Var.new "bar")
      scope.find_variable("foo").not_nil!.assignments.size.should eq 1
    end
  end
end
