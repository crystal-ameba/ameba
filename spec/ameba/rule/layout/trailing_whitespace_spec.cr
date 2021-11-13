require "../../../spec_helper"

module Ameba::Rule::Layout
  subject = TrailingWhitespace.new

  describe TrailingWhitespace do
    it "passes if all lines do not have trailing whitespace" do
      expect_no_issues subject, "no-whispace"
    end

    it "fails if there is a line with trailing whitespace" do
      source = expect_issue subject,
        "whitespace at the end  \n" \
        "                   # ^^ error: Trailing whitespace detected"

      expect_correction source, "whitespace at the end"
    end

    it "reports rule, pos and message" do
      source = Source.new "a = 1\n b = 2 ", "source.cr"
      subject.catch(source).should_not be_valid

      issue = source.issues.first
      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:2:7"
      issue.end_location.to_s.should eq "source.cr:2:7"
      issue.message.should eq "Trailing whitespace detected"
    end
  end
end
