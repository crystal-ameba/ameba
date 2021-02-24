require "../../../spec_helper"

module Ameba::Rule::Performance
  subject = AnyInsteadOfEmpty.new

  describe AnyInsteadOfEmpty do
    it "passes if there is no potential performance improvements" do
      source = Source.new %(
        [1, 2, 3].any?(&.zero?)
        [1, 2, 3].any?(String)
        [1, 2, 3].any?(1..3)
        [1, 2, 3].any? { |e| e > 1 }
      )
      subject.catch(source).should be_valid
    end

    it "reports if there is any? call without a block nor argument" do
      source = Source.new %(
        [1, 2, 3].any?
      )
      subject.catch(source).should_not be_valid
    end

    context "macro" do
      it "reports in macro scope" do
        source = Source.new %(
          {{ [1, 2, 3].any? }}
        )
        subject.catch(source).should_not be_valid
      end
    end

    it "reports rule, pos and message" do
      source = Source.new path: "source.cr", code: %(
        [1, 2, 3].any?
      )
      subject.catch(source).should_not be_valid
      issue = source.issues.first

      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:1:11"
      issue.end_location.to_s.should eq "source.cr:1:15"
      issue.message.should eq "Use `!{...}.empty?` instead of `{...}.any?`"
    end
  end
end
