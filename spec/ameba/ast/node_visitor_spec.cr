require "../../spec_helper"

module Ameba::AST
  rule = DummyRule.new
  source = Source.new ""

  describe NodeVisitor do
    {% for name in NODES %}
      describe "{{name}}" do
        it "allow to visit {{name}} node" do
          visitor = NodeVisitor.new rule, source
          nodes = Crystal::Parser.new("").parse
          nodes.accept visitor
        end
      end
    {% end %}
  end
end
