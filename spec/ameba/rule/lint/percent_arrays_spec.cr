require "../../../spec_helper"

module Ameba::Rule::Lint
  describe PercentArrays do
    subject = PercentArrays.new

    it "passes if percent arrays are written correctly" do
      expect_no_issues subject, <<-CRYSTAL
        %w[one two three]
        %w[1 2 3]
        %w[]

        %i[one two three]
        %i[1 2 3]
        %i[]
        CRYSTAL
    end

    it "fails if string percent array has commas" do
      expect_issue subject, <<-CRYSTAL
        puts %w[one, two]
           # ^^ error: Symbols `,"` may be unwanted in `%w` array literals
        CRYSTAL
    end

    it "fails if string percent array has quotes" do
      expect_issue subject, <<-CRYSTAL
        puts %w["one" "two"]
           # ^^ error: Symbols `,"` may be unwanted in `%w` array literals
        CRYSTAL
    end

    it "fails if symbols percent array has commas" do
      expect_issue subject, <<-CRYSTAL
        puts %i[one, two]
           # ^^ error: Symbols `,:` may be unwanted in `%i` array literals
        CRYSTAL
    end

    it "fails if symbols percent array has a colon" do
      expect_issue subject, <<-CRYSTAL
        puts %i[:one :two]
           # ^^ error: Symbols `,:` may be unwanted in `%i` array literals
        CRYSTAL
    end

    context "properties" do
      it "#string_array_unwanted_symbols" do
        rule = PercentArrays.new
        rule.string_array_unwanted_symbols = ","

        expect_no_issues rule, %(%w[one])
      end

      it "#symbol_array_unwanted_symbols" do
        rule = PercentArrays.new
        rule.symbol_array_unwanted_symbols = ","

        expect_no_issues rule, %(%i[:one])
      end
    end
  end
end
