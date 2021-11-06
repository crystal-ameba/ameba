require "../../../spec_helper"

module Ameba::Rule::Layout
  subject = TrailingBlankLines.new

  describe TrailingBlankLines do
    it "passes if there is a blank line at the end of a source" do
      expect_no_issues subject, "a = 1\n"
    end

    it "passes if source is empty" do
      expect_no_issues subject, ""
    end

    it "fails if there is no blank lines at the end" do
      source = expect_issue subject, "no-blankline # error: Trailing newline missing"
      expect_correction source, "no-blankline\n"
    end

    it "fails if there more then one blank line at the end of a source" do
      source = expect_issue subject, "a = 1\n \n # error: Excessive trailing newline detected"
      expect_no_corrections source
    end

    it "fails if last line is not blank" do
      source = expect_issue subject, "\n\n\n puts 22 # error: Trailing newline missing"
      expect_correction source, "\n\n\n puts 22\n"
    end

    context "when unnecessary blank line has been detected" do
      it "reports rule, pos and message" do
        source = Source.new "a = 1\n\n", "source.cr", normalize: false
        subject.catch(source).should_not be_valid

        issue = source.issues.first
        issue.rule.should_not be_nil
        issue.location.to_s.should eq "source.cr:3:1"
        issue.end_location.should be_nil
        issue.message.should eq "Excessive trailing newline detected"
      end
    end

    context "when final line has been missed" do
      it "reports rule, pos and message" do
        source = Source.new "a = 1", "source.cr", normalize: false
        subject.catch(source).should_not be_valid

        issue = source.issues.first
        issue.rule.should_not be_nil
        issue.location.to_s.should eq "source.cr:1:1"
        issue.end_location.should be_nil
        issue.message.should eq "Trailing newline missing"
      end
    end
  end
end
