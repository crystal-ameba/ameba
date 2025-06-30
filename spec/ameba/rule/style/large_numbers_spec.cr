require "../../../spec_helper"

private def it_transforms(number, expected, *, file = __FILE__, line = __LINE__)
  it "transforms large number #{number}", file, line do
    rule = Ameba::Rule::Style::LargeNumbers.new
    rule.int_min_digits = 5

    source = expect_issue rule, <<-CRYSTAL, number: number, file: file, line: line
      number = %{number}
             # ^{number} error: Large numbers should be written with underscores: `#{expected}`
      CRYSTAL

    expect_correction source, <<-CRYSTAL
      number = #{expected}
      CRYSTAL
  end
end

module Ameba::Rule::Style
  describe LargeNumbers do
    subject = LargeNumbers.new

    it "passes if large number does not require underscore" do
      expect_no_issues subject, <<-CRYSTAL
        1 2 3 4 5 6 7 8 9 10 11 12 13 14 15
        16 17 18 19 20 30 40 50 60 70 80 90
        100
        999
        1000
        1_000
        9999
        9_999
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

        1200.0
        1200.01
        1200.012
        CRYSTAL
    end

    it_transforms "10000", "10_000"
    it_transforms "+10000", "+10_000"
    it_transforms "-10000", "-10_000"

    it_transforms "9223372036854775808", "9_223_372_036_854_775_808"
    it_transforms "-9223372036854775808", "-9_223_372_036_854_775_808"
    it_transforms "+9223372036854775808", "+9_223_372_036_854_775_808"

    it_transforms "1_00000", "100_000"

    it_transforms "10000_i16", "10_000_i16"
    it_transforms "10000_i32", "10_000_i32"
    it_transforms "10000_i64", "10_000_i64"
    it_transforms "10000_i128", "10_000_i128"

    it_transforms "10000_u16", "10_000_u16"
    it_transforms "10000_u32", "10_000_u32"
    it_transforms "10000_u64", "10_000_u64"
    it_transforms "10000_u128", "10_000_u128"

    it_transforms "123456_f32", "123_456_f32"
    it_transforms "123456_f64", "123_456_f64"

    it_transforms "123456.5e-7_f32", "123_456.5e-7_f32"
    it_transforms "123456e10_f64", "123_456e10_f64"

    it_transforms "123456.5e-7", "123_456.5e-7"
    it_transforms "123456e10", "123_456e10"

    it_transforms "3.00_1", "3.001"
    it_transforms "3.0012", "3.001_2"
    it_transforms "3.00123", "3.001_23"
    it_transforms "3.001234", "3.001_234"
    it_transforms "3.0012345", "3.001_234_5"

    context "properties" do
      it "#int_min_digits" do
        rule = Rule::Style::LargeNumbers.new
        rule.int_min_digits = 10
        expect_no_issues rule, "1200000"
      end
    end
  end
end
