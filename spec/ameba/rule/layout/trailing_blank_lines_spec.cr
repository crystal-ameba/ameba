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

    it "passes if there is a single space between the last line and the end" do
      expect_no_issues subject, "a = 1\n \n"
    end

    it "fails if there is no blank lines at the end" do
      source = expect_issue subject, "no-blankline # error: Trailing newline missing"
      expect_correction source, "no-blankline\n"
    end

    it "fails if there is no blank lines at the end with CRLF" do
      source = expect_issue subject, "a = 1\r\nno-blankline # error: Trailing newline missing"
      expect_correction source, "a = 1\r\nno-blankline\r\n"
    end

    it "reports and autocorrects excessive trailing blank line (LF)" do
      source = expect_issue subject, <<-CRYSTAL
        a = 1

        # ^{} error: Excessive trailing newline detected
        \n\n\n
        CRYSTAL

      expect_correction source, "a = 1\n"
    end

    it "reports and autocorrects excessive trailing blank line (CRLF)" do
      source = expect_issue subject, <<-CRYSTAL
        a = 1

        # ^{} error: Excessive trailing newline detected
        \r\n\r\n
        CRYSTAL

      expect_correction source, "a = 1\r\n"
    end

    it "preserves trailing whitespace on the last code line before excessive newlines" do
      source = expect_issue subject, <<-CRYSTAL
        a = 1 #{""}

        # ^{} error: Excessive trailing newline detected
        \n\n
        CRYSTAL

      expect_correction source, "a = 1 \n"
    end

    it "reports and autocorrects whitespace-only file" do
      source = expect_issue subject, <<-CRYSTAL

        # ^{} error: Excessive trailing newline detected
        \n\n
        CRYSTAL

      expect_correction source, ""
    end

    it "fails if last line is not blank" do
      source = expect_issue subject, "\n\n\n puts 22 # error: Trailing newline missing"
      expect_correction source, "\n\n\n puts 22\n"
    end
  end
end
