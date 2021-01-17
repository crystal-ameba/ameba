require "../../../spec_helper"

module Ameba::AST
  describe TopLevelNodesVisitor do
    describe "#require_nodes" do
      it "returns require node" do
        source = Source.new %(
          require "foo"
          def bar; end
        )
        visitor = TopLevelNodesVisitor.new(source.ast)
        visitor.require_nodes.size.should eq 1
        visitor.require_nodes.first.to_s.should eq %q(require "foo")
      end
    end
  end
end
