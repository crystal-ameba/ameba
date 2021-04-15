require "../../../spec_helper"

module Ameba::Rule::Performance
  describe Base do
    subject = PerfRule.new

    describe "#catch" do
      it "ignores spec files" do
        source = Source.new("", "source_spec.cr")
        subject.catch(source).should be_valid
      end

      it "reports perf issues for non-spec files" do
        source = Source.new("", "source.cr")
        subject.catch(source).should_not be_valid
      end
    end
  end
end
