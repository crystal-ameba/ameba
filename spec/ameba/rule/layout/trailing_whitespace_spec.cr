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

    it "fails if a line ends with trailing \\r character" do
      source = expect_issue subject, <<-TEXT
        carriage return at the end\r
                                # ^ error: Trailing whitespace detected
        TEXT

      expect_correction source, "carriage return at the end"
    end

    it "fails if there is a line with trailing tab" do
      source = expect_issue subject, <<-TEXT
        tab at the end\t
                    # ^ error: Trailing whitespace detected
        TEXT

      expect_correction source, "tab at the end"
    end

    it "fails if there is a line with trailing whitespace" do
      source = expect_issue subject,
        "whitespace at the end  \n" \
        "                   # ^^ error: Trailing whitespace detected"

      expect_correction source, "whitespace at the end"
    end
  end
end
