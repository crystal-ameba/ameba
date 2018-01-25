require "../spec_helper"

module Ameba::Rule
  struct NoProperties < Rule::Base
    def test(source)
    end
  end

  describe Base do
    context ".rules" do
      it "returns a list of all rules" do
        rules = Rule.rules
        rules.should_not be_nil
        rules.should contain DummyRule
        rules.should contain NoProperties
      end

      it "should not include syntax rule" do
        Rule.rules.should_not contain Rule::Syntax
      end
    end

    context "properties" do
      subject = DummyRule.new

      it "is enabled by default" do
        subject.enabled.should be_true
      end

      it "has a description property" do
        subject.description.should_not be_nil
      end

      it "has excluded property" do
        subject.excluded.should be_nil
      end
    end

    describe "when a rule does not have defined properties" do
      it "is enabled by default" do
        NoProperties.new.enabled.should be_true
      end
    end

    describe "#excluded?" do
      it "returns false if a rule does no have a list of excluded source" do
        DummyRule.new.excluded?(Source.new "", "source.cr").should_not be_true
      end

      it "returns false if source is not excluded from this rule" do
        rule = DummyRule.new
        rule.excluded = %w(some_source.cr)
        rule.excluded?(Source.new "", "another_source.cr").should_not be_true
      end

      it "returns true if source is excluded from this rule" do
        rule = DummyRule.new
        rule.excluded = %w(source.cr)
        rule.excluded?(Source.new "", "source.cr").should be_true
      end

      pending "returns true if source matches the wildcard" do
        rule = DummyRule.new
        rule.excluded = %w(**/*.cr)
        rule.excluded?(Source.new "", "source.cr").should be_true
      end

      it "returns false if source does not match the wildcard" do
        rule = DummyRule.new
        rule.excluded = %w(*_spec.cr)
        rule.excluded?(Source.new "", "source.cr").should be_false
      end
    end
  end
end
