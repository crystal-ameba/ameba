require "../../spec_helper"

module Ameba::Rules
  subject = LargeNumbers.new

  describe LargeNumbers do
    it "passes if large number does not require underscore" do
      s = Source.new %q(
        1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20
        10
        100
        1_000
        10_000
        100_000
        200_000
        300_000
        400_000
        500_000
        600_000
        700_000
        800_000
        900_000
        1_000_000

       -9_223_372_036_854_775_808
        9_223_372_036_854_775_807

        141_592_654
        141_592_654.0
        141_592_654.001
        141_592_654.001_2
        141_592_654.001_23
        141_592_654.001_234
        141_592_654.001_234_5

        0b1101
        0o123
        0xFE012D
        0xfe012d
        0xfe012dd11

        1_i8
        12_i16
        123_i32
        1_234_i64

        12_u8
        123_u16
        1_234_u32
        9_223_372_036_854_775_808_u64
        9_223_372_036_854_775_808.000_123_456_789_f64

        +100_u32
        -900_000_i32

        1_234.5e-7
        11_234e10_f32
        +1.123
        -0.000_5
      )
      subject.catch(s).should be_valid
    end

    it "fails if large number requires underscore" do
      s = Source.new "10000"
      subject.catch(s).should_not be_valid
      s.errors.first.message.should match /10_000/
    end

    it "fails if large number with sign requires underscore" do
      s = Source.new "-10000"
      subject.catch(s).should_not be_valid
      s.errors.first.message.should match /-10_000/
    end

    it "reports rule, pos and message" do
      s = Source.new %q(
         1200000
      )
      subject.catch(s).should_not be_valid
      error = s.errors.first
      error.rule.should_not be_nil
      error.pos.should eq 2
      error.message.should match /1_200_000/
    end
  end
end
