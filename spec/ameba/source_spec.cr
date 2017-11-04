require "../spec_helper"

module Ameba
  describe Source do
    describe ".new" do
      it "allows to create a source by content and path" do
        s = Source.new("content", "path")
        s.path.should eq "path"
        s.content.should eq "content"
        s.lines.should eq ["content"]
      end
    end

    describe "#error" do
      it "adds and error" do
        s = Source.new ""
        s.error(DummyRule.new, 23, "Error!")
        s.errors.size.should eq 1
        s.errors.first.rule.should_not be_nil
        s.errors.first.pos.should eq 23
        s.errors.first.message.should eq "Error!"
      end
    end
  end
end
