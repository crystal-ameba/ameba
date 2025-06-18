require "../../../spec_helper"

module Ameba::Rule::Lint
  describe VoidOutsideLib do
    subject = VoidOutsideLib.new

    it "passes if Void is used in a fun def" do
      expect_no_issues subject, <<-CRYSTAL
        lib LibFoo
          fun foo(foo : Void) : Void
          fun bar(bar : Void*) : Void
        end
        CRYSTAL
    end

    it "passes if `Pointer(Void)` is used as a parameter type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        def foo(bar : Pointer(Void))
        end
        CRYSTAL
    end

    it "fails if `Void` is used as a parameter type restriction" do
      expect_issue subject, <<-CRYSTAL
        def foo(bar : Void)
                    # ^^^^ error: `Void` is not allowed in this context
        end
        CRYSTAL
    end

    it "passes if `Pointer(Void)` is used as return type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        def foo(bar) : Pointer(Void)
        end
        CRYSTAL
    end

    it "passes if `Pointer(Void) | Nil` is used as return type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        def foo(bar) : Pointer(Void) | Nil
        end
        CRYSTAL
    end

    it "fails if `Pointer(Void | Int32)` is used as return type restriction" do
      expect_issue subject, <<-CRYSTAL
        def foo(bar) : Pointer(Void | Int32)
                             # ^^^^ error: `Void` is not allowed in this context
        end
        CRYSTAL
    end

    it "fails if `Array(Void)` is used as return type restriction" do
      expect_issue subject, <<-CRYSTAL
        def foo(bar) : Array(Void)
                           # ^^^^ error: `Void` is not allowed in this context
        end
        CRYSTAL
    end

    it "passes if Void is used as name of a class" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          class Void
          end
        end
        CRYSTAL
    end

    it "fails if Void is inherited from" do
      expect_issue subject, <<-CRYSTAL
        struct Foo < Void
                   # ^^^^ error: `Void` is not allowed in this context
        end
        CRYSTAL
    end

    it "passes if Void is name of alias" do
      expect_no_issues subject, <<-CRYSTAL
        alias Void = Foo
        CRYSTAL
    end

    it "fails if Void is value of alias" do
      expect_issue subject, <<-CRYSTAL
        alias Foo = Void
                  # ^^^^ error: `Void` is not allowed in this context
        CRYSTAL
    end

    it "fails if `Void` is used for an uninitialized var" do
      expect_issue subject, <<-CRYSTAL
        var = uninitialized Void
                          # ^^^^ error: `Void` is not allowed in this context
        CRYSTAL
    end
  end
end
