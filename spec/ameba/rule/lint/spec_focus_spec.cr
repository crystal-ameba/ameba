require "../../../spec_helper"

module Ameba::Rule::Lint
  describe SpecFocus do
    subject = SpecFocus.new

    it "does not report if spec is not focused" do
      expect_no_issues subject, <<-CRYSTAL, path: "source_spec.cr"
        context "context" {}
        describe "describe" {}
        it "it" {}
        pending "pending" {}
        CRYSTAL
    end

    it "reports if there is a focused context" do
      expect_issue subject, <<-CRYSTAL, path: "source_spec.cr"
        context "context", focus: true do
                         # ^^^^^^^^^^^ error: Focused spec item detected
        end
        CRYSTAL
    end

    it "reports if there is a focused describe block" do
      expect_issue subject, <<-CRYSTAL, path: "source_spec.cr"
        describe "describe", focus: true do
                           # ^^^^^^^^^^^ error: Focused spec item detected
        end
        CRYSTAL
    end

    it "reports if there is a focused describe block (with block argument)" do
      expect_issue subject, <<-CRYSTAL, path: "source_spec.cr"
        describe "describe", focus: true, &block
                           # ^^^^^^^^^^^ error: Focused spec item detected
        CRYSTAL
    end

    it "reports if there is a focused it block" do
      expect_issue subject, <<-CRYSTAL, path: "source_spec.cr"
        it "it", focus: true do
               # ^^^^^^^^^^^ error: Focused spec item detected
        end
        CRYSTAL
    end

    it "reports if there is a focused pending block" do
      expect_issue subject, <<-CRYSTAL, path: "source_spec.cr"
        pending "pending", focus: true do
                         # ^^^^^^^^^^^ error: Focused spec item detected
        end
        CRYSTAL
    end

    it "reports if there is a spec item with `focus: false`" do
      expect_issue subject, <<-CRYSTAL, path: "source_spec.cr"
        it "it", focus: false do
               # ^^^^^^^^^^^^ error: Focused spec item detected
        end
        CRYSTAL
    end

    it "reports if there is a spec item with `focus: !true`" do
      expect_issue subject, <<-CRYSTAL, path: "source_spec.cr"
        it "it", focus: !true do
               # ^^^^^^^^^^^^ error: Focused spec item detected
        end
        CRYSTAL
    end

    it "does not report if there is non spec block with :focus" do
      expect_no_issues subject, <<-CRYSTAL, path: "source_spec.cr"
        some_method "foo", focus: true do
        end
        CRYSTAL
    end

    it "does not report if there is a parameterized focused spec item" do
      expect_no_issues subject, <<-CRYSTAL, path: "source_spec.cr"
        def assert_foo(focus = false)
          it "foo", focus: focus { yield }
        end
        CRYSTAL
    end

    it "does not report if there is a tagged item with :focus" do
      expect_no_issues subject, <<-CRYSTAL, path: "source_spec.cr"
        it "foo", tags: "focus" do
        end
        CRYSTAL
    end

    it "does not report if there are focused spec items without blocks" do
      expect_no_issues subject, <<-CRYSTAL, path: "source_spec.cr"
        describe "foo", focus: true
        context "foo", focus: true
        it "foo", focus: true
        pending "foo", focus: true
        CRYSTAL
    end

    it "does not report if there are focused items out of spec file" do
      expect_no_issues subject, <<-CRYSTAL
        describe "foo", focus: true {}
        context "foo", focus: true {}
        it "foo", focus: true {}
        pending "foo", focus: true {}
        CRYSTAL
    end
  end
end
