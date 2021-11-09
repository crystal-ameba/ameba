require "../../../spec_helper"

module Ameba::Rule::Style
  subject = NegatedConditionsInUnless.new

  describe NegatedConditionsInUnless do
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

    it "fails if there is a negated condition in unless" do
      expect_issue subject, <<-CRYSTAL
        unless !a
        # ^^^^^^^ error: Avoid negated conditions in unless blocks
          :nok
        end
        CRYSTAL
    end

    it "fails if one of AND conditions is negated" do
      expect_issue subject, <<-CRYSTAL
        unless a && !b
        # ^^^^^^^^^^^^ error: Avoid negated conditions in unless blocks
          :nok
        end
        CRYSTAL
    end

    it "fails if one of OR conditions is negated" do
      expect_issue subject, <<-CRYSTAL
        unless a || !b
        # ^^^^^^^^^^^^ error: Avoid negated conditions in unless blocks
          :nok
        end
        CRYSTAL
    end

    it "fails if one of inner conditions is negated" do
      expect_issue subject, <<-CRYSTAL
        unless a && (b || !c)
        # ^^^^^^^^^^^^^^^^^^^ error: Avoid negated conditions in unless blocks
          :nok
        end
        CRYSTAL
    end

    it "reports rule, pos and message" do
      s = Source.new ":nok unless !s.empty?", "source.cr"
      subject.catch(s).should_not be_valid

      issue = s.issues.first
      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:1:1"
      issue.end_location.to_s.should eq "source.cr:1:21"
      issue.message.should eq "Avoid negated conditions in unless blocks"
    end
  end
end
