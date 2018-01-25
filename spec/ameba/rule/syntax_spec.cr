require "../../spec_helper"

module Ameba::Rule
  describe Syntax do
    subject = Syntax.new

    it "passes if there is no invalid syntax" do
      s = Source.new %(
        def hello
          puts "totally valid"
        rescue e: Exception
          #
        end
      )
      subject.catch(s).should be_valid
    end

    it "fails if there is an invalid syntax" do
      s = Source.new %(
        def hello
          puts "invalid"
        rescue Exception => e
          #
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "reports rule, location and message" do
      s = Source.new "def hello end", "source.cr"
      subject.catch(s).should_not be_valid
      error = s.errors.first

      error.rule.should_not be_nil
      error.location.to_s.should eq "source.cr:1:11"
      error.message.should eq "unexpected token: end (expected ';' or newline)"
    end
  end
end
