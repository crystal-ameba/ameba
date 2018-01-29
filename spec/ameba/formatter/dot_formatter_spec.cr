require "../../spec_helper"

module Ameba::Formatter
  describe DotFormatter do
    output = IO::Memory.new
    subject = DotFormatter.new output

    describe "#started" do
      it "writes started message" do
        subject.started [Source.new ""]
        output.to_s.should eq "Inspecting 1 file.\n\n"
      end
    end

    describe "#source_finished" do
      it "writes valid source" do
        subject.source_finished Source.new ""
        output.to_s.should contain "."
      end

      it "writes invalid source" do
        s = Source.new ""
        s.error DummyRule.new, nil, "message"
        subject.source_finished s
        output.to_s.should contain "F"
      end
    end

    describe "#finished" do
      it "writes a final message" do
        subject.finished [Source.new ""]
        output.to_s.should contain "1 inspected, 0 failures."
      end

      it "writes the elapsed time" do
        subject.finished [Source.new ""]
        output.to_s.should contain "Finished in"
      end

      context "when errors found" do
        it "writes each error" do
          s = Source.new("").tap do |s|
            s.error(DummyRule.new, 1, 1, "DummyRuleError")
            s.error(NamedRule.new, 1, 2, "NamedRuleError")
          end
          subject.finished [s]
          log = output.to_s
          log.should contain "1 inspected, 2 failures."
          log.should contain "DummyRuleError"
          log.should contain "NamedRuleError"
        end

        it "does not write disabled errors" do
          s = Source.new ""
          s.error(DummyRule.new, 1, 1, "DummyRuleError", :disabled)
          subject.finished [s]
          output.to_s.should contain "1 inspected, 0 failures."
        end
      end
    end
  end
end
