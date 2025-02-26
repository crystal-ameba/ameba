require "../../../spec_helper"

module Ameba::Rule::Lint
  describe UnusedSelfAccess do
    subject = UnusedSelfAccess.new

    it "passes if self is used as receiver for a method def" do
      expect_no_issues subject, <<-CRYSTAL
        def self.foo
        end
        CRYSTAL
    end

    it "passes if self is used as object of call" do
      expect_no_issues subject, <<-CRYSTAL
        self.foo
        CRYSTAL
    end

    it "passes if self is used as method of call" do
      expect_no_issues subject, <<-CRYSTAL
        foo.self
        CRYSTAL
    end

    it "fails if self is unused in void context of class body" do
      expect_issue subject, <<-CRYSTAL
        class MyClass
          self
        # ^^^^ error: `self` is not used
        end
        CRYSTAL
    end

    it "fails if self is unused in void context of begin" do
      expect_issue subject, <<-CRYSTAL
        begin
          self
        # ^^^^ error: `self` is not used

          "foo"
        end
        CRYSTAL
    end

    it "fails if self is unused in void context of method def" do
      expect_issue subject, <<-CRYSTAL
        def foo
          self
        # ^^^^ error: `self` is not used
          "bar"
        end
        CRYSTAL
    end
  end
end
