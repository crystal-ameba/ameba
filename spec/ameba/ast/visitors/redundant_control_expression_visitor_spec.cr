require "../../../spec_helper"

module Ameba::AST
  describe RedundantControlExpressionVisitor do
    source = Source.new
    rule = RedundantControlExpressionRule.new

    node = as_node <<-CRYSTAL
      a = 1
      b = 2
      return a + b
      CRYSTAL
    subject = RedundantControlExpressionVisitor.new(rule, source, node)

    it "assigns valid attributes" do
      subject.rule.should eq rule
      subject.source.should eq source
      subject.node.should eq node
    end

    it "fires a callback with a valid node" do
      rule.nodes.size.should eq 1
      rule.nodes.first.to_s.should eq "return a + b"
    end
  end
end
