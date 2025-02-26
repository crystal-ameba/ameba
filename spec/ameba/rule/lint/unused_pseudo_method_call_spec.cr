require "../../../spec_helper"

module Ameba::Rule::Lint
  describe UnusedPseudoMethodCall do
    subject = UnusedPseudoMethodCall.new

    it "passes if typeof is unused" do
      expect_no_issues subject, <<-CRYSTAL
        typeof(1)
        CRYSTAL
    end

    it "passes if as is unused" do
      expect_no_issues subject, <<-CRYSTAL
        as(Int32)
        CRYSTAL
    end

    it "fails if pointerof is unused" do
      expect_issue subject, <<-CRYSTAL
        pointerof(Int32)
        # ^^^^^^^^^^^^^^ error: Pseudo-method call is not used
        CRYSTAL
    end

    it "fails if sizeof is unused" do
      expect_issue subject, <<-CRYSTAL
        sizeof(Int32)
        # ^^^^^^^^^^^ error: Pseudo-method call is not used
        CRYSTAL
    end

    it "fails if instance_sizeof is unused" do
      expect_issue subject, <<-CRYSTAL
        instance_sizeof(Int32)
        # ^^^^^^^^^^^^^^^^^^^^ error: Pseudo-method call is not used
        CRYSTAL
    end

    it "fails if alignof is unused" do
      expect_issue subject, <<-CRYSTAL
        alignof(Int32)
        # ^^^^^^^^^^^^ error: Pseudo-method call is not used
        CRYSTAL
    end

    it "fails if instance_alignof is unused" do
      expect_issue subject, <<-CRYSTAL
        instance_alignof(Int32)
        # ^^^^^^^^^^^^^^^^^^^^^ error: Pseudo-method call is not used
        CRYSTAL
    end

    it "fails if offsetof is unused" do
      expect_issue subject, <<-CRYSTAL
        offsetof(Int32, 1)
        # ^^^^^^^^^^^^^^^^ error: Pseudo-method call is not used
        CRYSTAL
    end

    it "fails if is_a? is unused" do
      expect_issue subject, <<-CRYSTAL
        foo = 1
        foo.is_a?(Int32)
        # ^^^^^^^^^^^^^^ error: Pseudo-method call is not used
        CRYSTAL
    end

    it "fails if as? is unused" do
      expect_issue subject, <<-CRYSTAL
        foo = 1
        foo.as?(Int32)
        # ^^^^^^^^^^^^ error: Pseudo-method call is not used
        CRYSTAL
    end

    it "fails if responds_to? is unused" do
      expect_issue subject, <<-CRYSTAL
        foo = 1
        foo.responds_to?(:bar)
        # ^^^^^^^^^^^^^^^^^^^^ error: Pseudo-method call is not used
        CRYSTAL
    end

    it "fails if nil? is unused" do
      expect_issue subject, <<-CRYSTAL
        foo = 1
        foo.nil?
        # ^^^^^^ error: Pseudo-method call is not used
        CRYSTAL
    end

    it "fails if prefix not is unused" do
      expect_issue subject, <<-CRYSTAL
        foo = 1
        !foo
        # ^^ error: Pseudo-method call is not used
        CRYSTAL
    end

    it "fails if suffix not is unused" do
      expect_issue subject, <<-CRYSTAL
        foo = 1
        foo.!
        # ^^^ error: Pseudo-method call is not used
        CRYSTAL
    end

    it "passes if pointerof is used as an assign value" do
      expect_no_issues subject, <<-CRYSTAL
        var = pointerof(Int32)
        CRYSTAL
    end

    it "passes if sizeof is used as an assign value" do
      expect_no_issues subject, <<-CRYSTAL
        var = sizeof(Int32)
        CRYSTAL
    end

    it "passes if instance_sizeof is used as an assign value" do
      expect_no_issues subject, <<-CRYSTAL
        var = instance_sizeof(Int32)
        CRYSTAL
    end

    it "passes if alignof is used as an assign value" do
      expect_no_issues subject, <<-CRYSTAL
        var = alignof(Int32)
        CRYSTAL
    end

    it "passes if instance_alignof is used as an assign value" do
      expect_no_issues subject, <<-CRYSTAL
        var = instance_alignof(Int32)
        CRYSTAL
    end

    it "passes if offsetof is used as an assign value" do
      expect_no_issues subject, <<-CRYSTAL
        var = offsetof(Int32, 1)
        CRYSTAL
    end

    it "passes if is_a? is used as an assign value" do
      expect_no_issues subject, <<-CRYSTAL
        var = is_a?(Int32)
        CRYSTAL
    end

    it "passes if as? is used as an assign value" do
      expect_no_issues subject, <<-CRYSTAL
        var = as?(Int32)
        CRYSTAL
    end

    it "passes if responds_to? is used as an assign value" do
      expect_no_issues subject, <<-CRYSTAL
        var = responds_to?(:foo)
        CRYSTAL
    end

    it "passes if nil? is used as an assign value" do
      expect_no_issues subject, <<-CRYSTAL
        var = nil?
        CRYSTAL
    end

    it "passes if prefix not is used as an assign value" do
      expect_no_issues subject, <<-CRYSTAL
        var = !true
        CRYSTAL
    end

    it "passes if suffix not is used as an assign value" do
      expect_no_issues subject, <<-CRYSTAL
        var = true.!
        CRYSTAL
    end
  end
end
