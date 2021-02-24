require "../../../spec_helper"

module Ameba::Rule::Style
  subject = IsAFilter.new

  describe IsAFilter do
    it "passes if there is no potential performance improvements" do
      source = Source.new %(
        [1, 2, nil].select(Int32)
        [1, 2, nil].reject(Nil)
      )
      subject.catch(source).should be_valid
    end

    it "reports if there is .is_a? call within select" do
      source = Source.new %(
        [1, 2, nil].select(&.is_a?(Int32))
      )
      subject.catch(source).should_not be_valid
    end

    it "reports if there is .nil? call within reject" do
      source = Source.new %(
        [1, 2, nil].reject(&.nil?)
      )
      subject.catch(source).should_not be_valid
    end

    context "properties" do
      it "allows to configure filter_names" do
        source = Source.new %(
          [1, 2, nil].reject(&.nil?)
        )
        rule = IsAFilter.new
        rule.filter_names = %w(select)
        rule.catch(source).should be_valid
      end
    end

    context "macro" do
      it "reports in macro scope" do
        source = Source.new %(
          {{ [1, 2, nil].reject(&.nil?) }}
        )
        subject.catch(source).should_not be_valid
      end
    end

    it "reports rule, pos and message" do
      source = Source.new path: "source.cr", code: %(
        [1, 2, nil].reject(&.nil?)
      )
      subject.catch(source).should_not be_valid
      source.issues.size.should eq 1

      issue = source.issues.first
      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:1:13"
      issue.end_location.to_s.should eq "source.cr:1:26"

      issue.message.should eq "Use `reject(Nil)` instead of `reject {...}`"
    end
  end
end
