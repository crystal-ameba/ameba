require "../../../spec_helper"

private def found?(code)
  Ameba::AST::LoopBreakVisitor.new(Crystal::Parser.new(code).parse).found?
end

module Ameba::AST
  describe LoopBreakVisitor do
    describe "#found?" do
      it "is false if there is no break" do
        found?("foo; next").should be_false
      end

      it "is true if there is a break" do
        found?("foo; break").should be_true
      end

      it "is true if there is a break within a branch" do
        found?("if foo; break; end").should be_true
      end

      it "is true if there is a break within an exception handler" do
        found?("begin; foo; rescue; break; end").should be_true
      end

      it "is false if the break is consumed by a nested loop" do
        found?("while foo; break; end").should be_false
        found?("until foo; break; end").should be_false
      end

      it "is false if the break is consumed by a block" do
        found?("foo.each { break }").should be_false
      end

      it "is false if the break is within a proc" do
        found?("-> { break }").should be_false
      end

      it "is true if there is a macro code, which might expand to a break" do
        found?("{% if flag?(:foo) %} break {% end %}").should be_true
        found?("{% for x in [1] %} foo {% end %}").should be_true
        found?("{{ :break.id }}").should be_true
      end
    end
  end
end
