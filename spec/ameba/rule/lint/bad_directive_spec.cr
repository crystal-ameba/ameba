require "../../../spec_helper"

module Ameba::Rule::Lint
  describe BadDirective do
    subject = BadDirective.new

    it "does not report if rule is correct" do
      expect_no_issues subject, <<-CRYSTAL
        # ameba:disable Lint/BadDirective
        CRYSTAL
    end

    it "reports if there is incorrect action" do
      expect_issue subject, <<-CRYSTAL
        # ameba:foo Lint/BadDirective
        # ^{} error: Bad action in comment directive: 'foo'. Possible values: disable, enable
        CRYSTAL
    end

    it "reports if there are incorrect rule names" do
      expect_issue subject, <<-CRYSTAL
        # ameba:enable BadRule1, BadRule2
        # ^{} error: Such rules do not exist: BadRule1, BadRule2
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
