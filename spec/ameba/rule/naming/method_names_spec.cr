require "../../../spec_helper"

private def it_reports_method_name(name, expected, *, file = __FILE__, line = __LINE__)
  it "reports method name #{expected}", file, line do
    rule = Ameba::Rule::Naming::MethodNames.new
    expect_issue rule, <<-CRYSTAL, name: name, file: file, line: line
      def %{name}; end
        # ^{name} error: Method name should be underscore-cased: `#{expected}`, not `%{name}`
      CRYSTAL
  end
end

module Ameba::Rule::Naming
  describe MethodNames do
    subject = MethodNames.new

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
  end
end
