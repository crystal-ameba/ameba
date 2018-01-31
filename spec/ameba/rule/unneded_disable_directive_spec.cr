require "../../spec_helper"

module Ameba::Rule
  describe UnneededDisableDirective do
    subject = UnneededDisableDirective.new

    it "passes if there are no comments" do
      s = Source.new %(
        a = 1
      )
      subject.catch(s).should be_valid
    end

    it "passes if there is disable directive" do
      s = Source.new %(
        a = 1 # my super var
      )
      subject.catch(s).should be_valid
    end

    it "passes if there is disable directive and it is needed" do
      s = Source.new %Q(
        a = 1 # ameba:disable #{NamedRule.name}
      )
      s.error NamedRule.new, 2, 1, "Alarm!", :disabled
      subject.catch(s).should be_valid
    end

    it "ignores commented out disable directive" do
      s = Source.new %Q(
        # # ameba:disable #{NamedRule.name}
        a = 1
      )
      s.error NamedRule.new, 3, 1, "Alarm!", :disabled
      subject.catch(s).should be_valid
    end

    it "failes if there is unneeded directive" do
      s = Source.new %Q(
        # ameba:disable #{NamedRule.name}
        a = 1
      )
      subject.catch(s).should_not be_valid
      s.errors.first.message.should eq(
        "Unnecessary disabling of #{NamedRule.name}"
      )
    end

    it "fails if there is inline unneeded directive" do
      s = Source.new %Q(a = 1 # ameba:disable #{NamedRule.name})
      subject.catch(s).should_not be_valid
      s.errors.first.message.should eq(
        "Unnecessary disabling of #{NamedRule.name}"
      )
    end

    it "detects mixed inline directives" do
      s = Source.new %Q(
        # ameba:disable Rule1, Rule2
        a = 1 # ameba:disable Rule3
      ), "source.cr"
      subject.catch(s).should_not be_valid
      s.errors.size.should eq 2
      s.errors.first.message.should contain "Rule1, Rule2"
      s.errors.last.message.should contain "Rule3"
    end

    it "reports error, location and message" do
      s = Source.new %Q(
        # ameba:disable Rule1, Rule2
        a = 1
      ), "source.cr"
      subject.catch(s).should_not be_valid
      error = s.errors.first
      error.rule.should_not be_nil
      error.location.to_s.should eq "source.cr:2:9"
      error.message.should eq "Unnecessary disabling of Rule1, Rule2"
    end
  end
end
