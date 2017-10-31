require "../../spec_helper"

module Ameba::Rules
  subject = TrailingBlankLines.new

  describe TrailingBlankLines do
    it "passes if there is no blank lines at the end" do
      source = Source.new "no-blankline"
      subject.catch(source).valid?.should be_true
    end

    it "fails if there is a blank line at the end of a source" do
      source = Source.new "a = 1\n \n "
      subject.catch(source).valid?.should be_false
    end

    it "passes if source is empty" do
      source = Source.new ""
      subject.catch(source).valid?.should be_true
    end

    it "passes if last line is not blank" do
      source = Source.new "\n\n\n puts 22"
      subject.catch(source).valid?.should be_true
    end

    it "reports rule, pos and message" do
      source = Source.new "a = 1\n\n "
      subject.catch(source)

      error = source.errors.first
      error.rule.should_not be_nil
      error.pos.should eq 3
      error.message.should eq "Blank lines detected at the end of the file"
    end
  end
end
