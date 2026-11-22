require "../../../spec_helper"

module Ameba::Rule::Lint
  describe RandZero do
    subject = RandZero.new

    it "passes if it is not rand(1) or rand(0)" do
      expect_no_issues subject, <<-CRYSTAL
        rand(1.0)
        rand(1_f32)
        rand(1e0)
        rand(0.11)
        rand(2)
        CRYSTAL
    end

    it "fails if it is rand(0)" do
      expect_issue subject, <<-CRYSTAL
        rand(0)
        # ^^^^^ error: `rand(0)` raises an `ArgumentError` due to an invalid bound
        rand(0x0)
        # ^^^^^^^ error: `rand(0)` raises an `ArgumentError` due to an invalid bound
        CRYSTAL
    end

    it "fails if it is rand(0.0)" do
      expect_issue subject, <<-CRYSTAL
        rand(0.0)
        # ^^^^^^^ error: `rand(0.0)` raises an `ArgumentError` due to an invalid bound
        rand(0_f32)
        # ^^^^^^^^^ error: `rand(0_f32)` raises an `ArgumentError` due to an invalid bound
        rand(0e0)
        # ^^^^^^^ error: `rand(0e0)` raises an `ArgumentError` due to an invalid bound
        rand(-0.0)
        # ^^^^^^^^ error: `rand(-0.0)` raises an `ArgumentError` due to an invalid bound
        CRYSTAL
    end

    it "fails if it is rand(1)" do
      expect_issue subject, <<-CRYSTAL
        rand(1)
        # ^^^^^ error: `rand(1)` always returns `0`
        rand(1_u8)
        # ^^^^^^^^ error: `rand(1_u8)` always returns `0`
        CRYSTAL
    end
  end
end
