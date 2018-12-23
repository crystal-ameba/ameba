require "../../../spec_helper"

module Ameba::Rule::Layout
  subject = TrailingBlankLines.new

  describe TrailingBlankLines do
    it "passes if there is no blank lines at the end" do
      source = Source.new "no-blankline"
      subject.catch(source).should be_valid
    end

    it "fails if there is a blank line at the end of a source" do
      source = Source.new "a = 1\n \n ", normalize: false
      subject.catch(source).should_not be_valid
    end

    it "passes if source is empty" do
      source = Source.new ""
      subject.catch(source).should be_valid
    end

    it "passes if last line is not blank" do
      source = Source.new "\n\n\n puts 22", normalize: false
      subject.catch(source).should be_valid
    end

    it "reports rule, pos and message" do
      source = Source.new "a = 1\n\n ", "source.cr", normalize: false
      subject.catch(source).should_not be_valid

      issue = source.issues.first
      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:2:1"
      issue.end_location.should be_nil
      issue.message.should eq "Blank lines detected at the end of the file"
    end
  end
end
