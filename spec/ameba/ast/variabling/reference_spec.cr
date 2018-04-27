require "../../../spec_helper"

module Ameba::AST
  describe Reference do
    it "is derived from a Variable" do
      node = Crystal::Var.new "foo"
      Reference.new(node).is_a?(Variable).should be_true
    end
  end
end
