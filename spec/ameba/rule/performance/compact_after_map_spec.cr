require "../../../spec_helper"

module Ameba::Rule::Performance
  subject = CompactAfterMap.new

  describe CompactAfterMap do
    it "passes if there is no potential performance improvements" do
      source = Source.new %(
        (1..3).compact_map(&.itself)
      )
      subject.catch(source).should be_valid
    end

    it "passes if there is map followed by a bang call" do
      source = Source.new %(
        (1..3).map(&.itself).compact!
      )
      subject.catch(source).should be_valid
    end

    it "reports if there is map followed by compact call" do
      source = Source.new %(
        (1..3).map(&.itself).compact
      )
      subject.catch(source).should_not be_valid
    end

    it "does not report if source is a spec" do
      source = Source.new %(
        (1..3).map(&.itself).compact
      ), "source_spec.cr"
      subject.catch(source).should be_valid
    end

    context "macro" do
      it "doesn't report in macro scope" do
        source = Source.new %(
          {{ [1, 2, 3].map(&.to_s).compact }}
        )
        subject.catch(source).should be_valid
      end
    end

    it "reports rule, pos and message" do
      s = Source.new %(
        (1..3).map(&.itself).compact
      ), "source.cr"
      subject.catch(s).should_not be_valid
      issue = s.issues.first

      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:1:8"
      issue.end_location.to_s.should eq "source.cr:1:29"
      issue.message.should eq "Use `compact_map {...}` instead of `map {...}.compact`"
    end
  end
end
