require "../../../spec_helper"

module Ameba::Rule::Performance
  subject = FlattenAfterMap.new

  describe FlattenAfterMap do
    it "passes if there is no potential performance improvements" do
      source = Source.new %(
        %w[Alice Bob].flat_map(&.chars)
      )
      subject.catch(source).should be_valid
    end

    it "reports if there is map followed by flatten call" do
      source = Source.new %(
        %w[Alice Bob].map(&.chars).flatten
      )
      subject.catch(source).should_not be_valid
    end

    it "does not report is source is a spec" do
      source = Source.new %(
        %w[Alice Bob].map(&.chars).flatten
      ), "source_spec.cr"
      subject.catch(source).should be_valid
    end

    context "macro" do
      it "doesn't report in macro scope" do
        source = Source.new %(
          {{ %w[Alice Bob].map(&.chars).flatten }}
        )
        subject.catch(source).should be_valid
      end
    end

    it "reports rule, pos and message" do
      s = Source.new %(
        %w[Alice Bob].map(&.chars).flatten
      ), "source.cr"
      subject.catch(s).should_not be_valid
      issue = s.issues.first

      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:1:15"
      issue.end_location.to_s.should eq "source.cr:1:35"
      issue.message.should eq "Use `flat_map {...}` instead of `map {...}.flatten`"
    end
  end
end
