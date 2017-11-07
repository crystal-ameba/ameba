require "../../spec_helper"

module Ameba
  subject = Rules::VariableNames.new

  private def it_reports_var_name(code, expected)
    it "reports method name #{expected}" do
      s = Source.new code
      Rules::VariableNames.new.catch(s).should_not be_valid
      s.errors.first.message.should contain expected
    end
  end

  describe Rules::VariableNames do
    it "passes if var names are underscore-cased" do
      s = Source.new %(
        class Greeting
          @@default_greeting = "Hello world"

          def initialize(@custom_greeting = nil)
          end

          def print_greeting
            greeting = @custom_greeting || @@default_greeting
            puts greeting
          end
        end
      )
      subject.catch(s).should be_valid
    end

    it_reports_var_name %(myBadNamedVar = 1), "my_bad_named_var"
    it_reports_var_name %(wrong_Name = 'y'), "wrong_name"

    it_reports_var_name %(
      class Greeting
        def initialize(@badNamed = nil)
        end
      end
    ), "bad_named"

    it_reports_var_name %(
      class Greeting
        @@defaultGreeting = "Hello world"
      end
    ), "default_greeting"

    it "reports rule, pos and message" do
      s = Source.new %(
        badName = "Yeah"
      ), "source.cr"
      subject.catch(s).should_not be_valid
      error = s.errors.first
      error.rule.should_not be_nil
      error.location.to_s.should eq "source.cr:2:9"
      error.message.should eq(
        "Var name should be underscore-cased: bad_name, not badName"
      )
    end
  end
end
