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

    it "fails for all comparison operators" do
      expect_issue subject, <<-CRYSTAL
          x == 2
        # ^^^^^^ error: Comparison operation has no effect
          x != 2
        # ^^^^^^ error: Comparison operation has no effect
          x =~ 2
        # ^^^^^^ error: Comparison operation has no effect
          x !~ 2
        # ^^^^^^ error: Comparison operation has no effect
          x === 2
        # ^^^^^^^ error: Comparison operation has no effect
          x < 2
        # ^^^^^ error: Comparison operation has no effect
          x <= 2
        # ^^^^^^ error: Comparison operation has no effect
          x > 2
        # ^^^^^ error: Comparison operation has no effect
          x >= 2
        # ^^^^^^ error: Comparison operation has no effect
          x <=> 2
        # ^^^^^^^ error: Comparison operation has no effect
        puts x
        CRYSTAL
    end

    it "fails for an unused top-level comparison" do
      expect_issue subject, <<-CRYSTAL
        x = 1
          x == 2
        # ^^^^^^ error: Comparison operation has no effect
        puts x
        CRYSTAL
    end

    it "fails for an unused comparison in a begin block" do
      expect_issue subject, <<-CRYSTAL
        begin
          x = 1
          x == 2
        # ^^^^^^ error: Comparison operation has no effect
          puts x
        end
        CRYSTAL
    end

    it "fails for unused comparisons in if/elsif/else bodies" do
      expect_issue subject, <<-CRYSTAL
        a = if x = 1
              x == 1
            # ^^^^^^ error: Comparison operation has no effect
              x == 2
            elsif true
              x == 1
            # ^^^^^^ error: Comparison operation has no effect
              x == 2
            else
              x == 2
            # ^^^^^^ error: Comparison operation has no effect
              x == 1
            # ^^^^^^ error: Comparison operation has no effect
              x == 3
            end
        CRYSTAL
    end

    it "fails for unused comparisons in a proc body" do
      expect_issue subject, <<-CRYSTAL
        a = -> {
          x == 1
        # ^^^^^^ error: Comparison operation has no effect
          "meow"
        }
        CRYSTAL
    end

    it "fails for unused comparison in if when not assigning" do
      expect_issue subject, <<-CRYSTAL
        if true
          x == 1
        # ^^^^^^ error: Comparison operation has no effect
        else
          x == 2
        # ^^^^^^ error: Comparison operation has no effect
        end
        CRYSTAL
    end

    it "fails on useless comparisons" do
      expect_issue subject, <<-CRYSTAL
        def hello
          if x == 3
            x < 1
          else
            x > 1
          end
        end

        def world
          if x == 3
            x < 1
          # ^^^^^ error: Comparison operation has no effect
          else
            x > 1
          # ^^^^^ error: Comparison operation has no effect
          end

          return
        end

        if x == 3
          x < 1
        # ^^^^^ error: Comparison operation has no effect
        else
          x > 1
        # ^^^^^ error: Comparison operation has no effect
        end

        a = if x == 3
              x > 1
            # ^^^^^ error: Comparison operation has no effect
              x < 1
            else
              x > 1
            end

        a = if begin
                x == 1
              # ^^^^^^ error: Comparison operation has no effect
                x == 3
              end
              x == 4
            end

          x == 4
        # ^^^^^^ error: Comparison operation has no effect
        CRYSTAL
    end
  end
end
