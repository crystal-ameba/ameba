require "../../spec_helper"

module Ameba::Rule
  subject = LineLength.new
  long_line = "*" * 81

  describe LineLength do
    it "passes if all lines are shorter than 80 symbols" do
      source = Source.new "short line"
      subject.catch(source).should be_valid
    end

    it "passes if line consists of 79 symbols" do
      source = Source.new "*" * 80
      subject.catch(source).should be_valid
    end

    it "fails if there is at least one line longer than 79 symbols" do
      source = Source.new long_line
      subject.catch(source).should_not be_valid
    end

    it "reports rule, pos and message" do
      source = Source.new long_line, "source.cr"
      subject.catch(source).should_not be_valid

      issue = source.issues.first
      issue.rule.should eq subject
      issue.location.to_s.should eq "source.cr:1:81"
      issue.message.should eq "Line too long"
    end

    context "properties" do
      it "allows to configure max length of the line" do
        source = Source.new long_line
        rule = LineLength.new
        rule.max_length = long_line.size
        rule.catch(source).should be_valid
      end
    end
  end
end
