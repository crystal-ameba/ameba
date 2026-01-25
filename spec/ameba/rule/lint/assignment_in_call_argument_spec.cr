require "../../../spec_helper"

module Ameba::Rule::Lint
  describe AssignmentInCallArgument do
    subject = AssignmentInCallArgument.new

    context "outside of a method call arguments" do
      it "ignores const assignments" do
        expect_no_issues subject, <<-CRYSTAL
          FOO = 1
          CRYSTAL
      end

      it "ignores bare assignments" do
        expect_no_issues subject, <<-CRYSTAL
          foo = 1
          CRYSTAL
      end

      it "ignores assignments within blocks" do
        expect_no_issues subject, <<-CRYSTAL
          foo do
            foo = 1
          end
          CRYSTAL
      end

      it "ignores assignments within methods" do
        expect_no_issues subject, <<-CRYSTAL
          def foo
            foo = 1
          end
          CRYSTAL
      end

      it "ignores assignments within classes" do
        expect_no_issues subject, <<-CRYSTAL
          class Foo
            foo = 1
          end
          CRYSTAL
      end
    end

    context "in stdlib macros" do
      it "ignores assignments within accessor macros" do
        expect_no_issues subject, <<-CRYSTAL
          class Foo
            class_getter foo = 1
            getter bar = 2
            property baz = 3
          end
          CRYSTAL
      end

      it "ignores assignments within `record` macro" do
        expect_no_issues subject, <<-CRYSTAL
          record Foo, foo = 1
          CRYSTAL
      end
    end

    it "ignores assignments within assignments" do
      expect_no_issues subject, <<-CRYSTAL
        self.foo = foo = 1
        CRYSTAL
    end

    it "ignores assignments within operator assignments" do
      expect_no_issues subject, <<-CRYSTAL
        self.foo += foo = 1
        CRYSTAL
    end

    it "ignores assignments within operator calls" do
      expect_no_issues subject, <<-CRYSTAL
        self.foo + (foo = 1)
        CRYSTAL
    end

    it "ignores assignment within a proc passed as a method call argument" do
      expect_no_issues subject, <<-CRYSTAL
        foo -> {
          bar = 1
        }
        CRYSTAL
    end

    it "ignores assignment within a proc passed as a method call named argument" do
      expect_no_issues subject, <<-CRYSTAL
        foo bar: -> {
          baz = 1
        }
        CRYSTAL
    end

    it "ignores assignment within a nested call" do
      expect_no_issues subject, <<-CRYSTAL
        foo(bar do
          baz = 1
        end)
        CRYSTAL
    end

    it "reports assignment within a method call argument" do
      expect_issue subject, <<-CRYSTAL
        foo a = 1
          # ^^^^^ error: Assignment within a call argument detected
        CRYSTAL
    end

    it "reports multiple assignments within a method call arguments" do
      expect_issue subject, <<-CRYSTAL
        foo a = 1, b = 2
          # ^^^^^ error: Assignment within a call argument detected
                 # ^^^^^ error: Assignment within a call argument detected
        CRYSTAL
    end

    it "reports operator assignment within a method call argument" do
      expect_issue subject, <<-CRYSTAL
        a = 0
        foo a += 1
          # ^^^^^^ error: Assignment within a call argument detected
        CRYSTAL
    end

    it "reports assignment within a method call named argument" do
      expect_issue subject, <<-CRYSTAL
        foo a: a = 1
             # ^^^^^ error: Assignment within a call argument detected
        CRYSTAL
    end
  end
end
