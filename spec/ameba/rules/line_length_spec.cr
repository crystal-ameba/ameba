require "../../spec_helper"

module Ameba::Rules
  subject = LineLength.new
  long_line = "*" * 80

  describe LineLength do
    it "passes if all lines are shorter than 80 symbols" do
      source = Source.new "short line"
      subject.catch(source).should be_valid
    end

    it "passes if line consists of 79 symbols" do
      source = Source.new "*" * 79
      subject.catch(source).should be_valid
    end

    it "fails if there is at least one line longer than 79 symbols" do
      source = Source.new long_line
      subject.catch(source).should_not be_valid
    end

    it "reports rule, pos and message" do
      source = Source.new long_line
      subject.catch(source).should_not be_valid

      error = source.errors.first
      error.rule.should eq subject
      error.pos.should eq 1
      error.message.should eq "Line too long (80 symbols)"
    end
  end
end
