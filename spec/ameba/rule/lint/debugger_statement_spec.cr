require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = DebuggerStatement.new

  describe DebuggerStatement do
    it "passes if there is no debugger statement" do
      expect_no_issues subject, <<-CRYSTAL
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
        CRYSTAL
    end

    it "fails if there is a debugger statement" do
      source = expect_issue subject, <<-CRYSTAL
        a = 2
        debugger
        # ^^^^^^ error: Possible forgotten debugger statement detected
        a = a + 1
        CRYSTAL

      expect_no_corrections source
    end
  end
end
