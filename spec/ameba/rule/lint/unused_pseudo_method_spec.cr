require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = UnusedPseudoMethod.new

  describe UnusedPseudoMethod do
    it "passes if return value of typeof or as isn't used" do
      expect_no_issues subject, <<-CRYSTAL
        typeof(1)
        as(Int32)
        CRYSTAL
    end

    it "fails if pseudo methods are unused top-level" do
      expect_issue subject, <<-CRYSTAL
        pointerof(Int32)
        # ^^^^^^^^^^^^^^ error: Pesudo-method is not used
        sizeof(Int32)
        # ^^^^^^^^^^^ error: Pesudo-method is not used
        instance_sizeof(Int32)
        # ^^^^^^^^^^^^^^^^^^^^ error: Pesudo-method is not used
        alignof(Int32)
        # ^^^^^^^^^^^^ error: Pesudo-method is not used
        instance_alignof(Int32)
        # ^^^^^^^^^^^^^^^^^^^^^ error: Pesudo-method is not used
        offsetof(Int32, 1)
        # ^^^^^^^^^^^^^^^^ error: Pesudo-method is not used
        is_a?(Int32)
        # ^^^^^^^^^^ error: Pesudo-method is not used
        as?(Int32)
        # ^^^^^^^^ error: Pesudo-method is not used
        responds_to?(:hello)
        # ^^^^^^^^^^^^^^^^^^ error: Pesudo-method is not used
        nil?
        # ^^ error: Pesudo-method is not used
        true.!
        # ^^^^ error: Pesudo-method is not used
        !true
        # ^^^ error: Pesudo-method is not used
        CRYSTAL
    end

    it "passes if pseudo methods are used as assign values" do
      expect_no_issues subject, <<-CRYSTAL
        var = pointerof(Int32)
        var = sizeof(Int32)
        var = instance_sizeof(Int32)
        var = alignof(Int32)
        var = instance_alignof(Int32)
        var = offsetof(Int32, 1)
        var = is_a?(Int32)
        var = as?(Int32)
        var = responds_to?(:hello)
        var = nil?
        var = true.!
        var = !true
        CRYSTAL
    end
  end
end
