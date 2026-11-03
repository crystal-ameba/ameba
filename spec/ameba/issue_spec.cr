require "../spec_helper"

module Ameba
  describe Issue do
    it "#without_correction drops only the correction" do
      location = Crystal::Location.new("path", 3, 2)
      issue = Issue.new code: "code",
        rule: DummyRule.new,
        location: location,
        end_location: location,
        message: "Blah",
        status: :disabled,
        block: ->(_corrector : Source::Corrector) { }
      issue.correctable?.should be_true

      uncorrectable = issue.without_correction
      uncorrectable.correctable?.should be_false
      uncorrectable.code.should eq "code"
      uncorrectable.rule.should eq issue.rule
      uncorrectable.location.should eq location
      uncorrectable.end_location.should eq location
      uncorrectable.message.should eq "Blah"
      uncorrectable.disabled?.should be_true
    end

    it "#as_corrected marks only a copy, keeping the rest" do
      issue = Issue.new code: "code",
        rule: DummyRule.new,
        location: nil,
        end_location: nil,
        message: "Blah",
        status: :disabled,
        block: ->(_corrector : Source::Corrector) { }
      issue.corrected?.should be_false

      corrected = issue.as_corrected
      corrected.corrected?.should be_true
      corrected.correctable?.should be_true
      corrected.code.should eq "code"
      corrected.message.should eq "Blah"
      corrected.disabled?.should be_true
      issue.corrected?.should be_false
    end

    it "#without_correction drops the corrected mark" do
      issue = Issue.new code: "",
        rule: DummyRule.new,
        location: nil,
        end_location: nil,
        message: "Blah"

      issue.as_corrected.without_correction.corrected?.should be_false
    end

    it "#without_correction accepts a new message" do
      issue = Issue.new code: "",
        rule: DummyRule.new,
        location: nil,
        end_location: nil,
        message: "Blah"

      issue.without_correction("Foo").message.should eq "Foo"
    end

    it "accepts rule and message" do
      issue = Issue.new code: "",
        rule: DummyRule.new,
        location: nil,
        end_location: nil,
        message: "Blah"

      issue.rule.should_not be_nil
      issue.message.should eq "Blah"
    end

    it "accepts location" do
      location = Crystal::Location.new("path", 3, 2)
      issue = Issue.new code: "",
        rule: DummyRule.new,
        location: location,
        end_location: nil,
        message: "Blah"

      issue.location.to_s.should eq location.to_s
      issue.end_location.should be_nil
    end

    it "accepts end_location" do
      location = Crystal::Location.new("path", 3, 2)
      issue = Issue.new code: "",
        rule: DummyRule.new,
        location: nil,
        end_location: location,
        message: "Blah"

      issue.location.should be_nil
      issue.end_location.to_s.should eq location.to_s
    end

    it "accepts status" do
      issue = Issue.new code: "",
        rule: DummyRule.new,
        location: nil,
        end_location: nil,
        message: "",
        status: :disabled

      issue.status.should eq Issue::Status::Disabled
      issue.disabled?.should be_true
      issue.enabled?.should be_false
    end

    it "sets status to :enabled by default" do
      issue = Issue.new code: "",
        rule: DummyRule.new,
        location: nil,
        end_location: nil,
        message: ""

      issue.status.should eq Issue::Status::Enabled
      issue.enabled?.should be_true
      issue.disabled?.should be_false
    end
  end
end
