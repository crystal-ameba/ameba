require "../../../spec_helper"

module Ameba::Rule::Internal
  describe NonExistentRule do
    subject = NonExistentRule.new

    it "does not report if the rule name is correct" do
      expect_no_issues subject, <<-CRYSTAL
        # ameba:disable Internal/NonExistentRule
        CRYSTAL
    end

    it "reports if there are incorrect rule names" do
      expect_issue subject, <<-CRYSTAL
        # ameba:disable BadRule1, BadRule2
                      # ^^^^^^^^^^^^^^^^^^ error: Such rules do not exist: `BadRule1`, `BadRule2`
        CRYSTAL
    end

    it "does not report if there no action and rules at all" do
      expect_no_issues subject, <<-CRYSTAL
        # ameba:
        CRYSTAL
    end

    it "does not report if there are no rules" do
      expect_no_issues subject, <<-CRYSTAL
        # ameba:enable
        # ameba:disable
        CRYSTAL
    end

    it "does not report if there are group names in the directive" do
      expect_no_issues subject, <<-CRYSTAL
        # ameba:disable Style Performance
        CRYSTAL
    end
  end
end
