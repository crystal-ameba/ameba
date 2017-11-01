require "../../spec_helper"

module Ameba::Rules
  subject = DebuggerStatement.new

  describe DebuggerStatement do
    it "passes if there is no debugger statement" do
      s = Source.new %(
        "this is not a debugger statement"
        s = "debugger"

        def debugger(program)
        end
        debugger ""

        class A
          def debugger
          end
        end
        A.new.debugger
      )
      subject.catch(s).should be_valid
    end

    it "fails if there is a debugger statement" do
      s = Source.new %(
        a = 2
        debugger
        a = a + 1
      )
      subject.catch(s).should_not be_valid
    end

    it "reports rule, pos and message" do
      s = Source.new "debugger"
      subject.catch(s).should_not be_valid

      error = s.errors.first
      error.rule.should_not be_nil
      error.pos.should eq 1
      error.message.should eq "Possible forgotten debugger statement detected"
    end
  end
end
