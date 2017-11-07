require "../../spec_helper"

module Ameba::Rules
  subject = NegatedConditionsInUnless.new

  describe NegatedConditionsInUnless do
    it "passes with a unless without negated condition" do
      s = Source.new %(
        unless a
          :ok
        end

        :ok unless b

        unless s.empty?
          :ok
        end
      )
      subject.catch(s).should be_valid
    end

    it "fails if there is a negated condition in unless" do
      s = Source.new %(
        unless !a
          :nok
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "fails if one of AND conditions is negated" do
      s = Source.new %(
        unless a && !b
          :nok
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "fails if one of OR conditions is negated" do
      s = Source.new %(
        unless a || !b
          :nok
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "fails if one of inner conditions is negated" do
      s = Source.new %(
        unless a && (b || !c)
          :nok
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "reports rule, pos and message" do
      s = Source.new ":nok unless !s.empty?", "source.cr"
      subject.catch(s).should_not be_valid

      error = s.errors.first
      error.rule.should_not be_nil
      error.location.to_s.should eq "source.cr:1:1"
      error.message.should eq "Avoid negated conditions in unless blocks"
    end
  end
end
