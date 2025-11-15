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
