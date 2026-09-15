require "../../../spec_helper"

module Ameba::Rule::Style
  describe NegatedConditionsInUnless do
    subject = NegatedConditionsInUnless.new

    it "passes with a unless without negated condition" do
      expect_no_issues subject, <<-CRYSTAL
        unless a
          :ok
        end

        :ok unless b

        unless s.empty?
          :ok
        end
        CRYSTAL
    end

    it "reports and autocorrects simple negated condition" do
      source = expect_issue subject, <<-CRYSTAL
        unless !a
        # ^^^^^^^ error: Avoid negated conditions in `unless` blocks
          :nok
        end
        CRYSTAL
      expect_correction source, <<-CRYSTAL
        if a
          :nok
        end
        CRYSTAL
    end

    it "reports and autocorrects negated method call" do
      source = expect_issue subject, <<-CRYSTAL
        unless !s.empty?
        # ^^^^^^^^^^^^^^ error: Avoid negated conditions in `unless` blocks
          :ok
        end
        CRYSTAL
      expect_correction source, <<-CRYSTAL
        if s.empty?
          :ok
        end
        CRYSTAL
    end

    it "reports and autocorrects negation with whitespace" do
      source = expect_issue subject, <<-CRYSTAL
        unless ! a
        # ^^^^^^^^ error: Avoid negated conditions in `unless` blocks
          :ok
        end
        CRYSTAL
      expect_correction source, <<-CRYSTAL
        if a
          :ok
        end
        CRYSTAL
    end

    it "reports and autocorrects parenthesized negated expression" do
      source = expect_issue subject, <<-CRYSTAL
        unless !(a || b)
        # ^^^^^^^^^^^^^^ error: Avoid negated conditions in `unless` blocks
          :ok
        end
        CRYSTAL
      expect_correction source, <<-CRYSTAL
        if (a || b)
          :ok
        end
        CRYSTAL
    end

    it "reports and autocorrects unless with else" do
      source = expect_issue subject, <<-CRYSTAL
        unless !a
        # ^^^^^^^ error: Avoid negated conditions in `unless` blocks
          :ok
        else
          :nok
        end
        CRYSTAL
      expect_correction source, <<-CRYSTAL
        if a
          :ok
        else
          :nok
        end
        CRYSTAL
    end

    it "reports and autocorrects suffix unless" do
      source = expect_issue subject, <<-CRYSTAL
        :ok unless !a
        # ^^^^^^^^^^^ error: Avoid negated conditions in `unless` blocks
        CRYSTAL
      expect_correction source, <<-CRYSTAL
        :ok if a
        CRYSTAL
    end

    it "reports and autocorrects multiline condition with negation" do
      source = expect_issue subject, <<-CRYSTAL
        unless !
        # ^^^^^^ error: Avoid negated conditions in `unless` blocks
          a
          :ok
        end
        CRYSTAL
      expect_correction source, <<-CRYSTAL
        if #{""}
          a
          :ok
        end
        CRYSTAL
    end

    it "fails if one of AND conditions is negated" do
      source = expect_issue subject, <<-CRYSTAL
        unless a && !b
        # ^^^^^^^^^^^^ error: Avoid negated conditions in `unless` blocks
          :nok
        end
        CRYSTAL
      expect_no_corrections source
    end

    it "fails if one of OR conditions is negated" do
      source = expect_issue subject, <<-CRYSTAL
        unless a || !b
        # ^^^^^^^^^^^^ error: Avoid negated conditions in `unless` blocks
          :nok
        end
        CRYSTAL
      expect_no_corrections source
    end

    it "fails if one of inner conditions is negated" do
      source = expect_issue subject, <<-CRYSTAL
        unless a && (b || !c)
        # ^^^^^^^^^^^^^^^^^^^ error: Avoid negated conditions in `unless` blocks
          :nok
        end
        CRYSTAL
      expect_no_corrections source
    end
  end
end
