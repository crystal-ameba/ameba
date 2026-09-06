require "../../../spec_helper"

module Ameba::Rule::Layout
  describe TrailingBlankLines do
    subject = TrailingBlankLines.new

    it "passes if there is a blank line at the end of a source" do
      expect_no_issues subject, "a = 1\n"
      expect_no_issues subject, "a = 1\r\n"
    end

    it "passes if source is empty" do
      expect_no_issues subject, ""
    end

    it "fails if there is no blank lines at the end" do
      source = expect_issue subject, "no-blankline # error: Trailing newline missing"
      expect_correction source, "no-blankline\n"
    end

    it "fails if there is no blank lines at the end with CRLF" do
      source = expect_issue subject, "a = 1\r\nno-blankline # error: Trailing newline missing"
      expect_correction source, "a = 1\r\nno-blankline\r\n"
    end

    it "reports and autocorrects if there is more than one blank line at the end of a source" do
      source = expect_issue subject, "a = 1\n \n # error: Excessive trailing newline detected"
      expect_correction source, "a = 1\n"
    end

    it "reports and autocorrects excessive trailing blank line (LF)" do
      source = expect_issue subject, "a = 1\n\n # error: Excessive trailing newline detected"
      expect_correction source, "a = 1\n"
    end

    it "reports and autocorrects excessive trailing blank line (CRLF)" do
      source = expect_issue subject, "a = 1\r\n\r\n # error: Excessive trailing newline detected"
      expect_correction source, "a = 1\r\n"
    end

    it "reports and autocorrects multiple excessive trailing blank lines" do
      source = expect_issue subject, "a = 1\n\n\n\n # error: Excessive trailing newline detected"
      expect_correction source, "a = 1\n"
    end

    it "preserves trailing whitespace on the last code line before excessive newlines" do
      source = expect_issue subject, "a = 1 \n\n # error: Excessive trailing newline detected"
      expect_correction source, "a = 1 \n"
    end

    it "reports and autocorrects single newline file" do
      source = expect_issue subject, "\n # error: Excessive trailing newline detected"
      expect_correction source, ""
    end

    it "reports and autocorrects whitespace-only file" do
      source = expect_issue subject, "\n\n # error: Excessive trailing newline detected"
      expect_correction source, ""
    end

    it "fails if last line is not blank" do
      source = expect_issue subject, "\n\n\n puts 22 # error: Trailing newline missing"
      expect_correction source, "\n\n\n puts 22\n"
    end

    context "when unnecessary blank line has been detected" do
      it "reports rule, pos and message" do
        source = Source.new("a = 1\n\n", "source.cr", normalize: false)
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
        source = Source.new("a = 1", "source.cr", normalize: false)
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
