require "../../../spec_helper"

module Ameba::Rule::Lint
  describe Syntax do
    subject = Syntax.new

    it "reports invalid UTF-8" do
      source = Source.new("# text \xFF\na = 1\n", "source.cr")
      subject.catch(source).should_not be_valid

      issue = source.issues.first
      issue.rule.should eq subject
      issue.message.should contain "malformed UTF-8"
      issue.location.to_s.should eq "source.cr:1:1"
    end

    it "passes if there is no invalid syntax" do
      expect_no_issues subject, <<-CRYSTAL
        def hello
          puts "totally valid"
        rescue ex : Exception
        end
        CRYSTAL
    end

    it "fails if there is an invalid syntax" do
      expect_issue subject, <<-CRYSTAL
        def hello
          puts "invalid"
        rescue Exception => e
                       # ^ error: expecting any of these tokens: ;, NEWLINE (not '=>')
        end
        CRYSTAL
    end

    it "has highest severity" do
      subject.severity.should eq Severity::Error
    end
  end
end
