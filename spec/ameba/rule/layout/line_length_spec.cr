require "../../../spec_helper"

module Ameba::Rule::Layout
  subject = LineLength.new
  long_line = "*" * (subject.max_length + 1)

  describe LineLength do
    it "passes if all lines are shorter than MaxLength symbols" do
      expect_no_issues subject, <<-CRYSTAL
        short line
        CRYSTAL
    end

    it "passes if line consists of MaxLength symbols" do
      expect_no_issues subject, <<-CRYSTAL
        #{"*" * subject.max_length}
        CRYSTAL
    end

    it "fails if there is at least one line longer than MaxLength symbols" do
      source = Source.new long_line
      subject.catch(source).should_not be_valid
    end

    it "reports rule, pos and message" do
      source = Source.new long_line, "source.cr"
      subject.catch(source).should_not be_valid

      issue = source.issues.first
      issue.rule.should eq subject
      issue.location.to_s.should eq "source.cr:1:#{subject.max_length + 1}"
      issue.end_location.should be_nil
      issue.message.should eq "Line too long"
    end

    context "properties" do
      it "#max_length" do
        rule = LineLength.new
        rule.max_length = long_line.size

        expect_no_issues rule, long_line
      end
    end
  end
end
