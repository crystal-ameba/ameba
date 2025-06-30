require "../../../spec_helper"

module Ameba::AST
  describe Reference do
    it "is derived from a Variable" do
      node = Crystal::Var.new "foo"
      ref = Reference.new(node, Scope.new as_node "foo = 1")
      ref.should be_a Variable
    end
  end
end
