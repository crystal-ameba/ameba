require "../../../spec_helper"

module Ameba::Rule::Lint
  describe UnneededDisableDirective do
    subject = UnneededDisableDirective.new

    it "passes if there are no comments" do
      expect_no_issues subject, <<-CRYSTAL
        a = 1
        CRYSTAL
    end

    it "passes if there is disable directive" do
      expect_no_issues subject, <<-CRYSTAL
        a = 1 # my super var
        CRYSTAL
    end

    it "doesn't report if there is disable directive and it is needed" do
      source = Source.new <<-CRYSTAL
        # ameba:disable #{NamedRule.name}
        a = 1
        CRYSTAL
      source.add_issue NamedRule.new, location: {2, 1},
        message: "Useless assignment", status: :disabled
      subject.catch(source).should be_valid
    end

    it "passes if there is inline disable directive and it is needed" do
      source = Source.new <<-CRYSTAL
        a = 1 # ameba:disable #{NamedRule.name}
        CRYSTAL
      source.add_issue NamedRule.new, location: {1, 1},
        message: "Alarm!", status: :disabled
      subject.catch(source).should be_valid
    end

    it "ignores commented out disable directive" do
      source = Source.new <<-CRYSTAL
        # # ameba:disable #{NamedRule.name}
        a = 1
        CRYSTAL
      source.add_issue NamedRule.new, location: {2, 1},
        message: "Alarm!", status: :disabled
      subject.catch(source).should be_valid
    end

    it "fails if there is unneeded directive" do
      expect_issue subject, <<-CRYSTAL, rule_name: NamedRule.name
        # ameba:disable %{rule_name}
        # ^{rule_name}^^^^^^^^^^^^^^ error: Unnecessary disabling of %{rule_name}
        a = 1
        CRYSTAL
    end

    it "fails if there is inline unneeded directive" do
      expect_issue subject, <<-CRYSTAL, rule_name: NamedRule.name
        a = 1 # ameba:disable %{rule_name}
            # ^{rule_name}^^^^^^^^^^^^^^^^ error: Unnecessary disabling of %{rule_name}
        CRYSTAL
    end

    it "detects mixed inline directives" do
      expect_issue subject, <<-CRYSTAL
        # ameba:disable Rule1, Rule2
        # ^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Unnecessary disabling of Rule1, Rule2
        a = 1 # ameba:disable Rule3
            # ^^^^^^^^^^^^^^^^^^^^^ error: Unnecessary disabling of Rule3
        CRYSTAL
    end

    it "fails if there is disabled UnneededDisableDirective" do
      source = Source.new <<-CRYSTAL
        # ameba:disable #{UnneededDisableDirective.rule_name}
        a = 1
        CRYSTAL
      source.add_issue UnneededDisableDirective.new, location: {2, 1},
        message: "Alarm!", status: :disabled
      subject.catch(source).should_not be_valid
    end
  end
end
