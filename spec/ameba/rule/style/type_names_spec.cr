require "../../../spec_helper"

module Ameba
  subject = Rule::Style::TypeNames.new

  private def it_reports_name(type, name, expected)
    it "reports type name #{expected}" do
      rule = Rule::Style::TypeNames.new
      expect_issue rule, <<-CRYSTAL, type: type, name: name
        %{type} %{name}; end
        # ^{type}^{name}^^^^ error: Type name should be camelcased: #{expected}, but it was %{name}
        CRYSTAL
    end
  end

  describe Rule::Style::TypeNames do
    it "passes if type names are camelcased" do
      expect_no_issues subject, <<-CRYSTAL
        class ParseError < Exception
        end

        module HTTP
          class RequestHandler
          end
        end

        alias NumericValue = Float32 | Float64 | Int32 | Int64

        lib LibYAML
        end

        struct TagDirective
        end

        enum Time::DayOfWeek
        end
        CRYSTAL
    end

    it_reports_name "class", "My_class", "MyClass"
    it_reports_name "module", "HTT_p", "HTTP"
    it_reports_name "lib", "Lib_YAML", "LibYAML"
    it_reports_name "struct", "Tag_directive", "TagDirective"
    it_reports_name "enum", "Time_enum::Day_of_week", "TimeEnum::DayOfWeek"

    it "reports alias name" do
      expect_issue subject, <<-CRYSTAL
        alias Numeric_value = Int32
        # ^{} error: Type name should be camelcased: NumericValue, but it was Numeric_value
        CRYSTAL
    end

    it "reports rule, pos and message" do
      s = Source.new %(
        class My_class
        end
      ), "source.cr"
      subject.catch(s).should_not be_valid
      issue = s.issues.first
      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:1:1"
      issue.end_location.to_s.should eq "source.cr:2:3"
      issue.message.should eq(
        "Type name should be camelcased: MyClass, but it was My_class"
      )
    end
  end
end
