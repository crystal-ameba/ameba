require "../../../spec_helper"

module Ameba::AST
  describe CountingVisitor do
    describe "#visit" do
      it "allow to visit ASTNode" do
        node = Crystal::Parser.new("").parse
        visitor = CountingVisitor.new node
        node.accept visitor
      end
    end

    describe "#count" do
      it "is 1 for an empty method" do
        node = Crystal::Parser.new("def hello; end").parse
        visitor = CountingVisitor.new node

        visitor.count.should eq 1
      end

      it "increases count for every conditional" do
        node = Crystal::Parser.new("def hello; if true; end end").parse
        visitor = CountingVisitor.new node

        visitor.count.should eq 2
      end

      it "increases count for every while loop" do
        node = Crystal::Parser.new("def hello; while true; end end").parse
        visitor = CountingVisitor.new node

        visitor.count.should eq 2
      end

      it "increases count for every until loop" do
        node = Crystal::Parser.new("def hello; until a < 10; end end").parse
        visitor = CountingVisitor.new node

        visitor.count.should eq 2
      end

      it "increases count for every for loop" do
        node = Crystal::Parser.new("def hello; while for a in 1..2; end end").parse
        visitor = CountingVisitor.new node

        visitor.count.should eq 2
      end

      it "increases count for every rescue" do
        node = Crystal::Parser.new("def hello; begin; rescue; end end").parse
        visitor = CountingVisitor.new node

        visitor.count.should eq 2
      end

      it "increases count for every when" do
        node = Crystal::Parser.new("def hello; case 1 when 1; end end").parse
        visitor = CountingVisitor.new node

        visitor.count.should eq 2
      end

      it "increases count for every or" do
        node = Crystal::Parser.new("def hello; true || false end").parse
        visitor = CountingVisitor.new node

        visitor.count.should eq 2
      end

      it "increases count for every and" do
        node = Crystal::Parser.new("def hello; true && false end").parse
        visitor = CountingVisitor.new node

        visitor.count.should eq 2
      end
    end
  end
end
