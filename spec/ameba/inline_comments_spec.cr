require "../spec_helper"

module Ameba
  describe InlineComments do
    it "disables a rule with a comment directive" do
      s = Source.new %Q(
        # ameba:disable #{NamedRule.name}
        Time.epoch(1483859302)
      )
      s.add_issue(NamedRule.new, location: {3, 12}, message: "Error!")
      s.should be_valid
    end

    it "disables a rule with a line that ends with a comment directive" do
      s = Source.new %Q(
        Time.epoch(1483859302) # ameba:disable #{NamedRule.name}
      )
      s.add_issue(NamedRule.new, location: {2, 12}, message: "Error!")
      s.should be_valid
    end

    it "does not disable a rule of a different name" do
      s = Source.new %Q(
        # ameba:disable WrongName
        Time.epoch(1483859302)
      )
      s.add_issue(NamedRule.new, location: {3, 12}, message: "Error!")
      s.should_not be_valid
    end

    it "disables a rule if multiple rule names provided" do
      s = Source.new %Q(
        # ameba:disable SomeRule LargeNumbers #{NamedRule.name} SomeOtherRule
        Time.epoch(1483859302)
      )
      s.add_issue(NamedRule.new, location: {3, 12}, message: "")
      s.should be_valid
    end

    it "disables a rule if multiple rule names are separated by comma" do
      s = Source.new %Q(
        # ameba:disable SomeRule, LargeNumbers, #{NamedRule.name}, SomeOtherRule
        Time.epoch(1483859302)
      )
      s.add_issue(NamedRule.new, location: {3, 12}, message: "")
      s.should be_valid
    end

    it "does not disable if multiple rule names used without required one" do
      s = Source.new %(
        # ameba:disable SomeRule, SomeOtherRule LargeNumbers
        Time.epoch(1483859302)
      )
      s.add_issue(NamedRule.new, location: {3, 12}, message: "")
      s.should_not be_valid
    end

    it "does not disable if comment directive has wrong place" do
      s = Source.new %Q(
        # ameba:disable #{NamedRule.name}
        #
        Time.epoch(1483859302)
      )
      s.add_issue(NamedRule.new, location: {4, 12}, message: "")
      s.should_not be_valid
    end

    it "does not disable if comment directive added to the wrong line" do
      s = Source.new %Q(
        if use_epoch? # ameba:disable #{NamedRule.name}
          Time.epoch(1483859302)
        end
      )
      s.add_issue(NamedRule.new, location: {3, 12}, message: "")
      s.should_not be_valid
    end

    it "does not disable if that is not a comment directive" do
      s = Source.new %Q(
        "ameba:disable #{NamedRule.name}"
        Time.epoch(1483859302)
      )
      s.add_issue(NamedRule.new, location: {3, 12}, message: "")
      s.should_not be_valid
    end

    it "does not disable if that is a commented out directive" do
      s = Source.new %Q(
        # # ameba:disable #{NamedRule.name}
        Time.epoch(1483859302)
      )
      s.add_issue(NamedRule.new, location: {3, 12}, message: "")
      s.should_not be_valid
    end

    it "does not disable if that is an inline commented out directive" do
      s = Source.new %Q(
        a = 1 # Disable it: # ameba:disable #{NamedRule.name}
      )
      s.add_issue(NamedRule.new, location: {2, 12}, message: "")
      s.should_not be_valid
    end
  end
end
