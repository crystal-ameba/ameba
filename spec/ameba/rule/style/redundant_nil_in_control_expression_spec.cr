require "../../../spec_helper"

module Ameba::Rule::Style
  describe RedundantNilInControlExpression do
    subject = RedundantNilInControlExpression.new

    it "passes for return with no expression" do
      expect_no_issues subject, <<-CRYSTAL
        def foo
          return if empty?
        end
        CRYSTAL
    end

    it "passes for return with expression" do
      expect_no_issues subject, <<-CRYSTAL
        def foo
          return :nil if empty?
        end
        CRYSTAL
    end

    it "reports `return nil` constructs" do
      source = expect_issue subject, <<-CRYSTAL
        def foo
          return nil if empty?
               # ^^^ error: Redundant `nil` detected
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def foo
          return if empty?
        end
        CRYSTAL
    end

    it "reports `return(nil)` constructs" do
      source = expect_issue subject, <<-CRYSTAL
        def foo
          return(nil) if empty?
               # ^^^ error: Redundant `nil` detected
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def foo
          return if empty?
        end
        CRYSTAL
    end

    it "reports `return( nil, )` constructs" do
      source = expect_issue subject, <<-CRYSTAL
        def foo
          return( nil, ) if empty?
                # ^^^ error: Redundant `nil` detected
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def foo
          return if empty?
        end
        CRYSTAL
    end

    it "reports multiline `return(nil)` constructs" do
      source = expect_issue subject, <<-CRYSTAL
        def foo
          return(
            nil
          # ^^^ error: Redundant `nil` detected
          ) if empty?
          :bar
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def foo
          return if empty?
          :bar
        end
        CRYSTAL
    end

    it "reports `next(nil)` and `break(nil)` constructs" do
      source = expect_issue subject, <<-CRYSTAL
        def foo
          %w[foo bar].any? do |word|
            next(nil) if word == "foo"
               # ^^^ error: Redundant `nil` detected
            break(nil) if word == "bar"
                # ^^^ error: Redundant `nil` detected
            word.ascii_only?
          end
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def foo
          %w[foo bar].any? do |word|
            next if word == "foo"
            break if word == "bar"
            word.ascii_only?
          end
        end
        CRYSTAL
    end

    it "reports `return(nil)` on the right side of a binary operator" do
      source = expect_issue subject, <<-CRYSTAL
        def foo(a)
          a || return(nil)
                    # ^^^ error: Redundant `nil` detected
          :bar
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def foo(a)
          a || return
          :bar
        end
        CRYSTAL
    end

    it "doesn't correct `return(nil)` if that would lose a comment" do
      source = expect_issue subject, <<-CRYSTAL
        def foo
          return(
            nil # comment
          # ^^^ error: Redundant `nil` detected
          ) if empty?
        end

        def bar
          return( # comment
            nil
          # ^^^ error: Redundant `nil` detected
          ) if empty?
        end
        CRYSTAL

      expect_no_corrections source
    end

    it "doesn't correct `return(nil)` if that would glue the keyword to what follows" do
      source = expect_issue subject, <<-CRYSTAL
        def foo
          return(nil)if empty?
               # ^^^ error: Redundant `nil` detected
          :bar
        end
        CRYSTAL

      expect_no_corrections source
    end

    it "reports `return nil` constructs (deep)" do
      expect_issue subject, <<-CRYSTAL
        def foo
          if foo?
            %w[foo bar].each do |v|
              return nil if v.empty?
                   # ^^^ error: Redundant `nil` detected
            end
          end
        end
        CRYSTAL
    end

    it "reports `break nil` constructs" do
      source = expect_issue subject, <<-CRYSTAL
        def foo
          %w[foo bar].any? do |word|
            break nil if word == "foo"
                # ^^^ error: Redundant `nil` detected
            word.ascii_only?
          end
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def foo
          %w[foo bar].any? do |word|
            break if word == "foo"
            word.ascii_only?
          end
        end
        CRYSTAL
    end

    it "reports `return nil` constructs with a line continuation" do
      source = expect_issue subject, <<-CRYSTAL
        def foo(x)
          return \\
            nil if x
          # ^^^ error: Redundant `nil` detected
          :bar
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def foo(x)
          return if x
          :bar
        end
        CRYSTAL
    end

    it "reports `next nil` constructs" do
      source = expect_issue subject, <<-CRYSTAL
        def foo
          %w[foo bar].any? do |word|
            next nil if word == "foo"
               # ^^^ error: Redundant `nil` detected
            word.ascii_only?
          end
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def foo
          %w[foo bar].any? do |word|
            next if word == "foo"
            word.ascii_only?
          end
        end
        CRYSTAL
    end
  end
end
