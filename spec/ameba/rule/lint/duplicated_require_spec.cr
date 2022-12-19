require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = DuplicatedRequire.new

  describe DuplicatedRequire do
    it "passes if there are no duplicated requires" do
      expect_no_issues subject, <<-CRYSTAL
        require "math"
        require "big"
        require "big/big_decimal"
        CRYSTAL
    end

    it "reports if there are a duplicated requires" do
      source = expect_issue subject, <<-CRYSTAL
        require "big"
        require "math"
        require "big"
        # ^{} error: Duplicated require of `big`
        CRYSTAL

      expect_no_corrections source
    end

    it "reports rule, pos and message" do
      source = Source.new <<-CRYSTAL, "source.cr"
        require "./thing"
        require "./thing"
        require "./another_thing"
        require "./another_thing"
        CRYSTAL

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
