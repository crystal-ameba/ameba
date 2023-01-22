require "../../../spec_helper"

module Ameba::Rule::Lint
  describe Syntax do
    subject = Syntax.new

    it "passes if there is no invalid syntax" do
      expect_no_issues subject, <<-CRYSTAL
        def hello
          puts "totally valid"
        rescue e : Exception
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
