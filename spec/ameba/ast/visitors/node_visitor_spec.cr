require "../../../spec_helper"

module Ameba::AST
  describe NodeVisitor do
    describe "visit" do
      it "allow to visit ASTNode" do
        rule = DummyRule.new
        visitor = NodeVisitor.new rule, Source.new("")

        nodes = Crystal::Parser.new("").parse
        nodes.accept visitor
      end
    end
  end
end
