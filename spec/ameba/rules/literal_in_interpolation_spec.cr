require "../../spec_helper"

module Ameba::Rules
  subject = LiteralInInterpolation.new

  describe LiteralInInterpolation do
    it "passes with good interpolation examples" do
      s = Source.new %q(
        name = "Ary"
        "Hello, #{name}"

        "#{name}"

        "Name size: #{name.size}"
      )
      subject.catch(s).valid?.should be_true
    end

    it "fails if there is useless interpolation" do
      [
        %q("#{:Ary}"),
        %q("#{[1, 2, 3]}"),
        %q("#{true}"),
        %q("#{false}"),
        %q("here are #{4} cats"),
      ].each do |str|
        subject.catch(Source.new str).valid?.should be_false
      end
    end

    it "reports rule, pos and message" do
      s = Source.new %q("#{4}")
      subject.catch(s).valid?.should be_false

      error = s.errors.first
      error.rule.should_not be_nil
      error.pos.should eq 1
      error.message.should eq "Literal value found in interpolation"
    end
  end
end
