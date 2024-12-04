require "../../../spec_helper"

module Ameba::Rule::Style
  describe MultilineCurlyBlock do
    subject = MultilineCurlyBlock.new

    it "doesn't report if a curly block is on a single line" do
      expect_no_issues subject, <<-CRYSTAL
        foo { :bar }
        CRYSTAL
    end

    it "doesn't report for `do`...`end` blocks" do
      expect_no_issues subject, <<-CRYSTAL
        foo do
          :bar
        end
        CRYSTAL
    end

    it "doesn't report for `do`...`end` blocks on a single line" do
      expect_no_issues subject, <<-CRYSTAL
        foo do :bar end
        CRYSTAL
    end

    it "reports if there is a multi-line curly block" do
      expect_issue subject, <<-CRYSTAL
        foo {
          # ^ error: Use `do`...`end` instead of curly brackets for multi-line blocks
          :bar
        }
        CRYSTAL
    end
  end
end
