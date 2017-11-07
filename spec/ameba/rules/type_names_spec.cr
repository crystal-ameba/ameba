require "../../spec_helper"

module Ameba
  subject = Rules::TypeNames.new

  private def it_reports_name(code, expected)
    it "reports type name #{expected}" do
      s = Source.new code
      Rules::TypeNames.new.catch(s).should_not be_valid
      s.errors.first.message.should contain expected
    end
  end

  describe Rules::TypeNames do
    it "passes if type names are camelcased" do
      s = Source.new %(
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
      )
      subject.catch(s).should be_valid
    end

    it_reports_name "class My_class; end", "MyClass"
    it_reports_name "module HTT_p; end", "HTTP"
    it_reports_name "alias Numeric_value = Int32", "NumericValue"
    it_reports_name "lib Lib_YAML; end", "LibYAML"
    it_reports_name "struct Tag_directive; end", "TagDirective"
    it_reports_name "enum Time_enum::Day_of_week; end", "TimeEnum::DayOfWeek"

    it "reports rule, pos and message" do
      s = Source.new %(
        class My_class
        end
      ), "source.cr"
      subject.catch(s).should_not be_valid
      error = s.errors.first
      error.rule.should_not be_nil
      error.location.to_s.should eq "source.cr:2:9"
      error.message.should eq(
        "Type name should be camelcased: MyClass, but it was My_class"
      )
    end
  end
end
