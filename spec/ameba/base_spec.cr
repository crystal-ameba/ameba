require "../spec_helper"

module Ameba::Rule
  struct NoProperties < Rule::Base
    def test(source)
    end
  end

  describe Base do
    context "properties" do
      subject = DummyRule.new

      it "is enabled by default" do
        subject.enabled.should be_true
      end

      it "has a description property" do
        subject.description.should_not be_nil
      end
    end

    describe "when a rule does not have defined properties" do
      it "is enabled by default" do
        NoProperties.new.enabled.should be_true
      end
    end
  end
end
