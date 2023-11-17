require "../../../spec_helper"

module Ameba
  subject = Rule::Naming::TypeNames.new

  private def it_reports_name(type, name, expected, *, file = __FILE__, line = __LINE__)
    it "reports type name #{expected}", file, line do
      rule = Rule::Naming::TypeNames.new
      expect_issue rule, <<-CRYSTAL, type: type, name: name, file: file, line: line
        %{type}   %{name}; end
        _{type} # ^{name} error: Type name should be camelcased: #{expected}, but it was %{name}
        CRYSTAL
    end
  end

  describe Rule::Naming::TypeNames do
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
            # ^^^^^^^^^^^^^ error: Type name should be camelcased: NumericValue, but it was Numeric_value
        CRYSTAL
    end
  end
end
