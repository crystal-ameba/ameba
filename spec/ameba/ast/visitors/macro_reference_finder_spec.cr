require "../../../spec_helper"

module Ameba::AST
  describe MacroReferenceFinder do
    describe "#references?" do
      {
        "{{ foo }}",
        "{{ foo.id }}",
        "{{ [foo] }}",
        %({{ "foo".id }}),
        "{% if foo != 1 %}{% end %}",
        "{% if foo!=1 %}{% end %}",
        "{% for x in foo %}{% end %}",
        "{% if true %}{% else %}{{ foo }}{% end %}",
      }.each do |code|
        it "returns true for #{code.inspect}" do
          node = Crystal::Parser.new(code).parse
          MacroReferenceFinder.new(node, "foo").references?.should be_true
        end
      end

      {
        "{{ bar }}",
        "{{ foo_bar }}",
        "{{ bar_foo }}",
        "{{ food }}",
        "{{ @foo }}",
        "{{ foo? }}",
        "{{ foo! }}",
        "{{ fooé }}",
      }.each do |code|
        it "returns false for #{code.inspect}" do
          node = Crystal::Parser.new(code).parse
          MacroReferenceFinder.new(node, "foo").references?.should be_false
        end
      end
    end
  end
end
