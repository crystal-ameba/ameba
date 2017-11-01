require "../../spec_helper"

module Ameba::AST
  rule = DummyRule.new
  source = Source.new ""

  describe "Traverse" do
    {% for name in NODE_VISITORS %}
      describe "{{name}}" do
        it "allow to visit {{name}} node" do
          visitor = {{name}}Visitor.new rule, source
          nodes = Crystal::Parser.new("").parse
          nodes.accept visitor
        end
      end
    {% end %}
  end
end
