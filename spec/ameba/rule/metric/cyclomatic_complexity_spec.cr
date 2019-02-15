require "../../../spec_helper"

module Ameba::Rule::Metric
  subject = CyclomaticComplexity.new

  describe CyclomaticComplexity do
    it "passes for empty methods" do
      source = Source.new %(
        def hello
        end
      )
      subject.catch(source).should be_valid
    end

    it "a reports one issue for a super complex method" do
      source = Source.new %(
        def hello(a, b, c)
          if a && b && c
            begin
              while true
                return if false && b
              end
              ""
            rescue
              ""
            end
          end
        end
      ), "source.cr"
      subject.catch(source).should_not be_valid

      issue = source.issues.first
      issue.rule.should eq subject
      issue.location.to_s.should eq "source.cr:1:1"
      issue.end_location.to_s.should eq "source.cr:12:3"
      issue.message.should eq "Cyclomatic complexity too high"
    end
  end
end
