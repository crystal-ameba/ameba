require "../../../spec_helper"

module Ameba::Rule::Lint
  describe UnusedGenericOrUnion do
    subject = UnusedGenericOrUnion.new

    it "passes if a generic is used in a top-level type declaration" do
      expect_no_issues subject, <<-CRYSTAL
        foo : Bar?
        CRYSTAL
    end

    it "passes if a union is used in a top-level type declaration" do
      expect_no_issues subject, <<-CRYSTAL
        foo : Bar | Baz
        CRYSTAL
    end

    it "passes if a generic is used in an assign" do
      expect_no_issues subject, <<-CRYSTAL
        foo = Bar?
        CRYSTAL
    end

    it "passes if a union is used in an assign" do
      expect_no_issues subject, <<-CRYSTAL
        foo = Bar | Baz
        CRYSTAL
    end

    it "passes if a generic or union is used in a cast" do
      expect_no_issues subject, <<-CRYSTAL
        foo.as(Bar?)
        bar.as?(Baz | Qux)
        CRYSTAL
    end

    it "passes if a generic or union is used as a method argument" do
      expect_no_issues subject, <<-CRYSTAL
        puts StaticArray(Int32, 10)
        CRYSTAL
    end

    it "passes if a generic is used as a method call object" do
      expect_no_issues subject, <<-CRYSTAL
        MyClass(String).new
        CRYSTAL
    end

    it "passes if something that looks like a union but isn't is top-level" do
      expect_no_issues subject, <<-CRYSTAL
        # Not a union
        Foo | "Bar"
        CRYSTAL
    end

    it "passes for an unused path" do
      expect_no_issues subject, "Foo"
    end

    it "passes if a generic is used for a parameter type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        def foo(bar : Baz?)
        end
        CRYSTAL
    end

    it "passes if a generic is used for a method return type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        def foo : Baz?
        end
        CRYSTAL
    end

    it "passes if a union is used for a parameter type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        def foo(bar : Baz | Qux)
        end
        CRYSTAL
    end

    it "passes if a union is used for a method return type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        def foo : Baz | Qux
        end
        CRYSTAL
    end

    it "fails for an unused top-level generic" do
      expect_issue subject, <<-CRYSTAL
        String?
        # ^^^^^ error: Generic is not used
        StaticArray(Int32, 10)
        # ^^^^^^^^^^^^^^^^^^^^ error: Generic is not used
        CRYSTAL
    end

    it "fails for an unused top-level union" do
      expect_issue subject, <<-CRYSTAL
        Int32 | Float64 | Nil
        # ^^^^^^^^^^^^^^^^^^^ error: Union is not used
        CRYSTAL
    end

    it "fails for an unused top-level union of self, typeof, and underscore" do
      expect_issue subject, <<-CRYSTAL
        self | typeof(1) | _
        # ^^^^^^^^^^^^^^^^^^ error: Union is not used
        CRYSTAL
    end

    it "fails if a generic is in void of method body" do
      expect_issue subject, <<-CRYSTAL
        def foo
          Float64?
        # ^^^^^^^^ error: Generic is not used
          nil
        end
        CRYSTAL
    end

    it "fails if a union is in void of method body" do
      expect_issue subject, <<-CRYSTAL
        def foo
          Bar | Baz
        # ^^^^^^^^^ error: Union is not used
          nil
        end
        CRYSTAL
    end

    it "fails if a generic is in void of class body" do
      expect_issue subject, <<-CRYSTAL
        class MyClass
          String?
        # ^^^^^^^ error: Generic is not used
        end
        CRYSTAL
    end
  end
end
