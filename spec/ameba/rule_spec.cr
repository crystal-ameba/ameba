require "../../spec/spec_helper"

module Ameba
  describe RULES do
    it "contains available rules" do
      Ameba::RULES.empty?.should be_false
    end
  end

  describe Rule do
    describe "#catch" do
      it "accepts and returns source" do
        s = Source.new "", ""
        DummyRule.new.catch(s).should eq s
      end
    end

    describe "#name" do
      it "returns name of the rule" do
        DummyRule.new.name.should eq "DummyRule"
      end
    end
  end
end
