require "../../../spec_helper"

module Ameba::Rule::Internal
  describe BadDirective do
    subject = BadDirective.new

    it "does not report if action is correct" do
      expect_no_issues subject, <<-CRYSTAL
        # ameba:disable Internal/BadDirective
        CRYSTAL
    end

    it "reports if there is incorrect action" do
      expect_issue subject, <<-CRYSTAL
        # ameba:foo Internal/BadDirective
              # ^^^ error: Bad action in comment directive: `foo`. Possible values: `disable`, `enable`
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
  end
end
