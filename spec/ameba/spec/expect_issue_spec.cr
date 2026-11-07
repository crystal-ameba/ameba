require "../../spec_helper"

module Ameba
  describe "#expect_correction" do
    it "passes if the correction matches" do
      source = Source.new("foo\n")
      BreakingCorrectionRule.new.catch(source)

      expect_correction source, "bar\n"
    end

    it "fails if the correction doesn't match" do
      source = Source.new("foo\n")
      BreakingCorrectionRule.new.catch(source)

      expect_raises(::Spec::AssertionFailed, "Expected correction:") do
        expect_correction(source, "baz\n")
      end
    end

    it "fails if the correction breaks the syntax" do
      source = Source.new("bar\n")
      BreakingCorrectionRule.new.catch(source)

      expect_raises(::Spec::AssertionFailed, "Expected correction to keep the code parsable") do
        expect_correction(source, "bar)\n")
      end
    end

    it "accepts unparsable code if it wasn't parsable in the first place" do
      source = Source.new("bar (\n")
      BreakingCorrectionRule.new.catch(source)

      expect_correction source, "bar) (\n"
    end
  end
end
