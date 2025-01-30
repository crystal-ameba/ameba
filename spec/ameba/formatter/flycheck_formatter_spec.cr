require "../../spec_helper"

module Ameba::Formatter
  describe FlycheckFormatter do
    output = IO::Memory.new
    subject = FlycheckFormatter.new output

    before_each do
      output.clear
    end

    context "problems not found" do
      it "reports nothing" do
        subject.source_finished Source.new ""
        subject.output.to_s.empty?.should be_true
      end
    end

    context "when problems found" do
      it "reports an issue" do
        s = Source.new "a = 1", "source.cr"
        s.add_issue DummyRule.new, {1, 2}, "message"

        subject.source_finished s
        subject.output.to_s.should eq(
          "source.cr:1:2: C: [#{DummyRule.rule_name}] message\n"
        )
      end

      it "properly reports multi-line message" do
        s = Source.new "a = 1", "source.cr"
        s.add_issue DummyRule.new, {1, 2}, "multi\nline"

        subject.source_finished s
        subject.output.to_s.should eq(
          "source.cr:1:2: C: [#{DummyRule.rule_name}] multi line\n"
        )
      end

      it "reports nothing if location was not set" do
        s = Source.new "a = 1", "source.cr"
        s.add_issue DummyRule.new, Crystal::Nop.new, "message"

        subject.source_finished s
        subject.output.to_s.should eq ""
      end
    end
  end
end
