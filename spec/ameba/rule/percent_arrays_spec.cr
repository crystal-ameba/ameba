require "../../spec_helper"

module Ameba::Rule
  describe PercentArrays do
    subject = PercentArrays.new

    it "passes if percent arrays are written correctly" do
      s = Source.new %q(
        %i(one two three)
        %w(one two three)

        %i(1 2 3)
        %w(1 2 3)

        %i()
        %w()
      )
      subject.catch(s).should be_valid
    end

    it "fails if string percent array has commas" do
      s = Source.new %( %w(one, two) )
      subject.catch(s).should_not be_valid
    end

    it "fails if string percent array has quotes" do
      s = Source.new %( %w("one" "two") )
      subject.catch(s).should_not be_valid
    end

    it "fails if symbols percent array has commas" do
      s = Source.new %( %i(one, two) )
      subject.catch(s).should_not be_valid
    end

    it "fails if symbols percent array has a colon" do
      s = Source.new %( %i(:one :two) )
      subject.catch(s).should_not be_valid
    end

    it "reports rule, location and message for %i" do
      s = Source.new %(
        %i(:one)
      ), "source.cr"

      subject.catch(s).should_not be_valid
      error = s.errors.first
      error.rule.should_not be_nil
      error.location.to_s.should eq "source.cr:2:9"
      error.message.should eq(
        "Symbols `,:` may be unwanted in %i array literals"
      )
    end

    it "reports rule, location and message for %w" do
      s = Source.new %(
        %w("one")
      ), "source.cr"

      subject.catch(s).should_not be_valid
      error = s.errors.first
      error.rule.should_not be_nil
      error.location.to_s.should eq "source.cr:2:9"
      error.message.should eq(
        "Symbols `,\"` may be unwanted in %w array literals"
      )
    end
  end
end
