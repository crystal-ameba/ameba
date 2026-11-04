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

    {
      "return a"                => [false],
      "x || return a"           => [true],
      "x && y || return a"      => [true],
      "x || (return a)"         => [false],
      "x ? (return a) : 1"      => [false],
      "x ? return a : 1"        => [true],
      "x ? 1 : return a"        => [true],
      "if x; return a; end"     => [false],
      "unless x; return a; end" => [false],
      "return a if x"           => [false],
    }.each do |code, operands|
      it "tells operands of an operator for `#{code}`" do
        operand_rule = RedundantControlExpressionRule.new
        RedundantControlExpressionVisitor.new(operand_rule, Source.new, as_node(code))
        operand_rule.operands.should eq operands
      end
    end

    it "doesn't carry the operand state over to the following nodes" do
      operand_rule = RedundantControlExpressionRule.new
      conditional = as_node <<-CRYSTAL
        if a
          x || return 1
        else
          return 2
        end
        CRYSTAL

      RedundantControlExpressionVisitor.new(operand_rule, Source.new, conditional)
      operand_rule.operands.should eq [true, false]
    end
  end
end
