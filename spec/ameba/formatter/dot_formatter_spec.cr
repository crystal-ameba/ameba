require "../../spec_helper"

module Ameba::Formatter
  describe DotFormatter do
    output = IO::Memory.new
    subject = DotFormatter.new output

    before_each do
      output.clear
    end

    describe "#started" do
      it "writes started message" do
        subject.started [Source.new]
        output.to_s.should eq "Inspecting 1 file\n\n"
      end
    end

    describe "#source_finished" do
      it "writes valid source" do
        subject.source_finished Source.new
        output.to_s.should contain "."
      end

      it "writes invalid source" do
        source = Source.new
        source.add_issue DummyRule.new, Crystal::Nop.new, "message"

        subject.source_finished source
        output.to_s.should contain "F"
      end
    end

    describe "#finished" do
      it "writes a final message" do
        subject.finished [Source.new]
        output.to_s.should contain "1 inspected, 0 failures"
      end

      it "writes the elapsed time" do
        subject.finished [Source.new]
        output.to_s.should contain "Finished in"
      end

      context "when issues found" do
        it "writes each issue" do
          source = Source.new
          source.add_issue(DummyRule.new, {1, 1}, "DummyRuleError")
          source.add_issue(NamedRule.new, {1, 2}, "NamedRuleError")

          subject.finished [source]
          log = output.to_s
          log.should contain "1 inspected, 2 failures"
          log.should contain "DummyRuleError"
          log.should contain "NamedRuleError"
        end

        it "writes affected code by default" do
          source = Source.new <<-CRYSTAL
            a = 22
            puts a
            CRYSTAL
          source.add_issue(DummyRule.new, {1, 5}, "DummyRuleError")

          subject.finished [source]
          log = output.to_s
          log = subject.deansify(log).should_not be_nil
          log.should contain "> a = 22"
          log.should contain "      ^"
        end

        it "writes severity" do
          source = Source.new <<-CRYSTAL
            a = 22
            puts a
            CRYSTAL
          source.add_issue(DummyRule.new, {1, 5}, "DummyRuleError")

          subject.finished [source]
          log = output.to_s
          log.should contain "[C]"
        end

        it "doesn't write affected code if it is disabled" do
          source = Source.new <<-CRYSTAL
            a = 22
            puts a
            CRYSTAL
          source.add_issue(DummyRule.new, {1, 5}, "DummyRuleError")

          formatter = DotFormatter.new output
          formatter.config[:without_affected_code] = true
          formatter.finished [source]

          log = output.to_s
          log = formatter.deansify(log).should_not be_nil
          log.should_not contain "> a = 22"
          log.should_not contain "      ^"
        end

        it "does not write disabled issues" do
          source = Source.new
          source.add_issue(DummyRule.new, {1, 1}, "DummyRuleError", status: :disabled)
          source.add_issue(NamedRule.new, {1, 2}, "NamedRuleError")

          subject.finished [source]
          log = output.to_s
          log.should_not contain "DummyRuleError"
          log.should contain "1 inspected, 1 failure"
        end
      end
    end
  end
end
