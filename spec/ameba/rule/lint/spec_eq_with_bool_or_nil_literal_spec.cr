require "../../../spec_helper"

module Ameba::Rule::Lint
  describe SpecEqWithBoolOrNilLiteral do
    subject = SpecEqWithBoolOrNilLiteral.new

    it "does not report `eq` method calls that are not arguments to `should`" do
      expect_no_issues subject, <<-CRYSTAL, path: "source_spec.cr"
        foo.bar? eq true
        foo.bar? eq false
        foo.bar? eq nil
        CRYSTAL
    end

    it "does not report if `be_true` / `be_false` expectation is used" do
      expect_no_issues subject, <<-CRYSTAL, path: "source_spec.cr"
        foo.is_a?(String).should be_true
        foo.is_a?(Int32).should be_false
        foo.is_a?(String).should_not be_true
        foo.is_a?(Int32).should_not be_false
        CRYSTAL
    end

    it "does not report if `be_nil` expectation is used" do
      expect_no_issues subject, <<-CRYSTAL, path: "source_spec.cr"
        foo.as?(Symbol).should be_nil
        foo.as?(Symbol).should_not be_nil
        CRYSTAL
    end

    it "reports if `eq` expectation with bool literal is used" do
      source = expect_issue subject, <<-CRYSTAL, path: "source_spec.cr"
        foo.is_a?(String).should eq true
                               # ^^^^^^^ error: Use `be_true` instead of `eq(true)` expectation
        foo.is_a?(Int32).should eq false
                              # ^^^^^^^^ error: Use `be_false` instead of `eq(false)` expectation
        foo.is_a?(String).should_not eq true
                                   # ^^^^^^^ error: Use `be_true` instead of `eq(true)` expectation
        foo.is_a?(Int32).should_not eq false
                                  # ^^^^^^^^ error: Use `be_false` instead of `eq(false)` expectation
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo.is_a?(String).should be_true
        foo.is_a?(Int32).should be_false
        foo.is_a?(String).should_not be_true
        foo.is_a?(Int32).should_not be_false
        CRYSTAL
    end

    it "reports if `eq` expectation with nil literal is used" do
      source = expect_issue subject, <<-CRYSTAL, path: "source_spec.cr"
        foo.as?(Symbol).should eq nil
                             # ^^^^^^ error: Use `be_nil` instead of `eq(nil)` expectation
        foo.as?(Symbol).should_not eq nil
                                 # ^^^^^^ error: Use `be_nil` instead of `eq(nil)` expectation
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo.as?(Symbol).should be_nil
        foo.as?(Symbol).should_not be_nil
        CRYSTAL
    end
  end
end
