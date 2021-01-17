require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = DuplicatedRequire.new

  describe DuplicatedRequire do
    it "passes if there are no duplicated requires" do
      source = Source.new %(
        require "math"
        require "big"
        require "big/big_decimal"
      )
      subject.catch(source).should be_valid
    end

    it "reports if there are a duplicated requires" do
      source = Source.new %(
        require "big"
        require "math"
        require "big"
      )
      subject.catch(source).should_not be_valid
    end

    it "reports rule, pos and message" do
      source = Source.new %(
        require "./thing"
        require "./thing"
        require "./another_thing"
        require "./another_thing"
      ), "source.cr"

      subject.catch(source).should_not be_valid

      issue = source.issues.first
      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:2:1"
      issue.end_location.to_s.should eq ""
      issue.message.should eq "Duplicated require of `./thing`"

      issue = source.issues.last
      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:4:1"
      issue.end_location.to_s.should eq ""
      issue.message.should eq "Duplicated require of `./another_thing`"
    end
  end
end
