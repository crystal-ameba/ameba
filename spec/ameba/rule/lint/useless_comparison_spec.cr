require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = UselessComparison.new

  describe UselessComparison do
    it "passes if comparisons are significant" do
      expect_no_issues subject, <<-CRYSTAL
        a = 1 == "1"
        b = begin
          2 == "3"
        end

        if c == b
          puts "meow"
        end

        def test
          1 == 2
        end
        CRYSTAL
    end

    it "fails for an unused top-level comparison" do
      expect_issue subject, <<-CRYSTAL
        x = 1
        x == 2
        # ^ error: Comparison operation has no effect
        puts x
        CRYSTAL
    end

    it "fails for an unused comparison in a begin block" do
      expect_issue subject, <<-CRYSTAL
        begin
          x = 1
          x == 2
          # ^ error: Comparison operation has no effect
          puts x
        end
        CRYSTAL
    end

    it "fails for unused comparisons in if/elsif/else bodies" do
      expect_issue subject, <<-CRYSTAL
        if x = 1
          x == 1
          # ^ error: Comparison operation has no effect
          x == 2
        elsif true
          x == 1
          # ^ error: Comparison operation has no effect
          x == 2
        else
          x == 2
          # ^ error: Comparison operation has no effect
          x == 1
          # ^ error: Comparison operation has no effect
          x == 3
        end
        CRYSTAL
    end

    it "fails for unused comparisons in a proc body" do
      expect_issue subject, <<-CRYSTAL
        a = -> {
          x == 1
          # ^ error: Comparison operation has no effect
          "meow"
        }
        CRYSTAL
    end
  end
end
