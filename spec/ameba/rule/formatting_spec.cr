require "../../spec_helper"

module Ameba
  describe Rule::Formatting do
    subject = Rule::Formatting.new

    it "passes if source is formatted" do
      s = Source.new "def method(a, b)\n  a + b\nend\n"
      subject.catch(s).should be_valid
    end

    it "reports if source is not formatted" do
      s = Source.new %(
        def method(a,b)
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "reports if source can not be formatted" do
      s = Source.new %(
        def method(a, b)
          a + b
      )
      subject.catch(s).should_not be_valid
    end

    context "when fail_if_error set to false" do
      it "does not report if source can not be formatted" do
        rule = Rule::Formatting.new
        rule.fail_if_error = false
        s = Source.new %(
          def method(a, b)
            a + b
        )
        rule.catch(s).should be_valid
      end
    end

    it "reports rule, location and message" do
      s = Source.new %(
        class A
          ONE = 1
          TWO = 2
          THREE = 3
        end
      ), "source.cr"
      subject.catch(s).should_not be_valid

      error = s.errors.first
      error.rule.should_not be_nil
      error.location.to_s.should eq "source.cr:1:1"
      error.message.should eq(
        "Use built-in formatter to format this source"
      )
    end
  end
end
