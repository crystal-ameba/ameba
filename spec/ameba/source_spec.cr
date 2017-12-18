require "../spec_helper"

module Ameba
  describe Source do
    describe ".new" do
      it "allows to create a source by code and path" do
        s = Source.new("code", "path")
        s.path.should eq "path"
        s.code.should eq "code"
        s.lines.should eq ["code"]
      end
    end

    describe "#error" do
      it "adds and error" do
        s = Source.new "", "source.cr"
        s.error(DummyRule.new, s.location(23, 2), "Error!")
        s.should_not be_valid

        error = s.errors.first
        error.rule.should_not be_nil
        error.location.to_s.should eq "source.cr:23:2"
        error.message.should eq "Error!"
      end
    end

    describe "#fullpath" do
      it "returns a relative path of the source" do
        s = Source.new "", "./source_spec.cr"
        s.fullpath.should contain "source_spec.cr"
      end

      it "returns fullpath if path is blank" do
        s = Source.new "", ""
        s.fullpath.should_not be_nil
      end
    end
  end
end
