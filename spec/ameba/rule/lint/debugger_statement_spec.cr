require "../../../spec_helper"

module Ameba::Rule::Lint
  describe DebuggerStatement do
    subject = DebuggerStatement.new

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
        # ^^^^^^ error: Possibly forgotten `debugger` statement detected
        a = a + 1
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        a = 2

        a = a + 1
        CRYSTAL
    end

    it "fails if there is a debugger statement with a suffix condition" do
      source = expect_issue subject, <<-CRYSTAL
        a = 2
        debugger if a > 1
        # ^^^^^^ error: Possibly forgotten `debugger` statement detected
        debugger unless a.zero?
        # ^^^^^^ error: Possibly forgotten `debugger` statement detected
        a = a + 1
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        a = 2


        a = a + 1
        CRYSTAL
    end
  end
end
