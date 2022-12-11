require "../../../spec_helper"

module Ameba::Rule::Metrics
  subject = CyclomaticComplexity.new
  complex_method = <<-CRYSTAL
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
    CRYSTAL

  describe CyclomaticComplexity do
    it "passes for empty methods" do
      expect_no_issues subject, <<-CRYSTAL
        def hello
        end
        CRYSTAL
    end

    it "reports one issue for a complex method" do
      rule = CyclomaticComplexity.new
      rule.max_complexity = 5

      source = Source.new(complex_method, "source.cr")
      rule.catch(source).should_not be_valid

      issue = source.issues.first
      issue.rule.should eq rule
      issue.location.to_s.should eq "source.cr:1:5"
      issue.end_location.to_s.should eq "source.cr:1:9"
      issue.message.should eq "Cyclomatic complexity too high [8/5]"
    end

    it "doesn't report an issue for an increased threshold" do
      rule = CyclomaticComplexity.new
      rule.max_complexity = 100

      expect_no_issues rule, complex_method
    end
  end
end
