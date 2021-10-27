require "../../../spec_helper"

module Ameba
  subject = Rule::Style::MethodNames.new

  private def it_reports_method_name(name, expected)
    it "reports method name #{expected}" do
      rule = Rule::Style::MethodNames.new
      expect_issue rule, <<-CRYSTAL, name: name
        def %{name}; end
          # ^{name} error: Method name should be underscore-cased: #{expected}, not %{name}
        CRYSTAL
    end
  end

  describe Rule::Style::MethodNames do
    it "passes if method names are underscore-cased" do
      expect_no_issues subject, <<-CRYSTAL
        class Person
          def first_name
          end

          def date_of_birth
          end

          def homepage_url
          end

          def valid?
          end

          def name
          end
        end
        CRYSTAL
    end

    it_reports_method_name "firstName", "first_name"
    it_reports_method_name "date_of_Birth", "date_of_birth"
    it_reports_method_name "homepageURL", "homepage_url"

    it "reports rule, pos and message" do
      s = Source.new %(
        def bad_Name(a)
        end
      ), "source.cr"
      subject.catch(s).should_not be_valid
      issue = s.issues.first
      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:1:5"
      issue.end_location.to_s.should eq "source.cr:1:12"
      issue.message.should eq(
        "Method name should be underscore-cased: bad_name, not bad_Name"
      )
    end
  end
end
