require "../spec_helper"

module Ameba
  describe Reportable do
    describe "#add_issue" do
      it "adds a new issue for node" do
        source = Source.new path: "source.cr"
        source.add_issue(DummyRule.new, Crystal::Nop.new, "Error!")

        issue = source.issues.first
        issue.rule.should_not be_nil
        issue.location.to_s.should be_empty
        issue.message.should eq "Error!"
      end

      it "adds a new issue by line and column number" do
        source = Source.new path: "source.cr"
        source.add_issue(DummyRule.new, {23, 2}, "Error!")

        issue = source.issues.first
        issue.rule.should_not be_nil
        issue.location.to_s.should eq "source.cr:23:2"
        issue.message.should eq "Error!"
      end
    end

    describe "#valid?" do
      it "returns true if no issues added" do
        source = Source.new path: "source.cr"
        source.should be_valid
      end

      it "returns false if there are issues added" do
        source = Source.new path: "source.cr"
        source.add_issue DummyRule.new, {22, 2}, "ERROR!"
        source.should_not be_valid
      end
    end
  end
end
