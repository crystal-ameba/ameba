require "../../../spec_helper"

module Ameba::Rule::Style
  describe WhileTrue do
    subject = WhileTrue.new

    it "passes if there is no `while true`" do
      expect_no_issues subject, <<-CRYSTAL
        a = 1
        loop do
          a += 1
          break if a > 5
        end
        CRYSTAL
    end

    it "fails if there is `while true`" do
      source = expect_issue subject, <<-CRYSTAL
        a = 1
        while true
        # ^^^^^^^^ error: While statement using `true` literal as condition
          a += 1
          break if a > 5
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        a = 1
        loop do
          a += 1
          break if a > 5
        end
        CRYSTAL
    end

    it "fails without correcting `while true` declaring variables used after it" do
      source = expect_issue subject, <<-CRYSTAL
        def foo
          while true
        # ^^^^^^^^^^ error: While statement using `true` literal as condition
            a = 1
            break
          end
          a
        end

        def bar
          while true
        # ^^^^^^^^^^ error: While statement using `true` literal as condition
            a = 1
            break
          end
          [1].map { a }
        end

        def baz
          while true
        # ^^^^^^^^^^ error: While statement using `true` literal as condition
            a = 1
            break
          end
          a = 2 if rand > 0.5
          a
        end
        CRYSTAL

      expect_no_corrections source
    end

    it "fails and corrects `while true` declaring variables not used after it" do
      source = expect_issue subject, <<-CRYSTAL
        def foo
          a = 0
          while true
        # ^^^^^^^^^^ error: While statement using `true` literal as condition
            a = 1
            b = 2
            break if a < b
          end
          a
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def foo
          a = 0
          loop do
            a = 1
            b = 2
            break if a < b
          end
          a
        end
        CRYSTAL
    end

    it "corrects outer `while true` if its variables are used only within it" do
      source = expect_issue subject, <<-CRYSTAL
        def foo
          while true
        # ^^^^^^^^^^ error: While statement using `true` literal as condition
            while true
          # ^^^^^^^^^^ error: While statement using `true` literal as condition
              a = 1
              break
            end
            break a
          end
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def foo
          loop do
            while true
              a = 1
              break
            end
            break a
          end
        end
        CRYSTAL
    end
  end
end
