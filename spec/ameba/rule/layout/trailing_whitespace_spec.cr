require "../../../spec_helper"

module Ameba::Rule::Layout
  describe TrailingWhitespace do
    subject = TrailingWhitespace.new

    it "passes if all lines do not have trailing whitespace" do
      expect_no_issues subject, "no-whitespace"
    end

    it "passes a line ends with trailing CRLF sequence" do
      expect_no_issues subject, "no-whitespace\r\n"
    end

    it "fails if there is a line with trailing whitespace" do
      source = expect_issue subject,
        "whitespace at the end  \n" \
        "                   # ^^ error: Trailing whitespace detected"

      expect_correction source, "whitespace at the end"
    end
  end
end
