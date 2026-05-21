require "../../spec_helper"

module Ameba
  describe Rule::Base do
    describe ".from_yaml" do
      it "ignores unknown attributes" do
        DummyRule.from_yaml("{ not: there }").should be_a(DummyRule)
      end
    end

    describe ".deprecated?" do
      it "returns false if the rule is not deprecated" do
        DummyRule.deprecated?.should be_false
      end

      it "returns true if the rule is deprecated" do
        DeprecatedRule.deprecated?.should be_true
      end
    end

    describe ".deprecation_reason" do
      it "returns nil if the rule is not deprecated" do
        DummyRule.deprecation_reason.should be_nil
      end

      it "returns the deprecation reason if the rule is deprecated" do
        DeprecatedRule.deprecation_reason.should eq "This rule is deprecated"
      end
    end

    describe "#catch" do
      it "accepts and returns source" do
        source = Source.new
        DummyRule.new.catch(source).should eq source
      end
    end

    describe "#name" do
      it "returns name of the rule" do
        DummyRule.new.name.should eq "Ameba/DummyRule"
      end
    end

    describe "#group" do
      it "returns a group rule belongs to" do
        DummyRule.new.group.should eq "Ameba"
      end
    end
  end

  describe Rule do
    describe ".rules" do
      it "returns a list of all defined rules" do
        Rule.rules.includes?(DummyRule).should be_true
      end
    end
  end
end
