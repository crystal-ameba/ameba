require "../../../spec_helper"

private def it_reports_var_name(name, value, expected, *, file = __FILE__, line = __LINE__)
  it "reports variable name #{expected}", file, line do
    rule = Ameba::Rule::Naming::VariableNames.new
    expect_issue rule, <<-CRYSTAL, name: name, file: file, line: line
        %{name} = #{value}
      # ^{name} error: Variable name should be underscore-cased: `#{expected}`, not `%{name}`
      CRYSTAL
  end
end

module Ameba::Rule::Naming
  describe VariableNames do
    subject = VariableNames.new

    it "passes if var names are underscore-cased" do
      expect_no_issues subject, <<-CRYSTAL
        class Greeting
          @@default_greeting = "Hello world"

          def initialize(@custom_greeting = nil)
          end

          def print_greeting
            greeting = @custom_greeting || @@default_greeting
            puts greeting
          end
        end
        CRYSTAL
    end

    it_reports_var_name "myBadNamedVar", "1", "my_bad_named_var"
    it_reports_var_name "wrong_Name", "'y'", "wrong_name"

    it "reports instance variable name" do
      expect_issue subject, <<-CRYSTAL
        class Greeting
          def initialize(@badNamed = nil)
                       # ^ error: Variable name should be underscore-cased: `@bad_named`, not `@badNamed`
          end
        end
        CRYSTAL
    end

    it "reports method with multiple instance variables" do
      expect_issue subject, <<-CRYSTAL
        class Location
          def at(@startLocation = nil, @endLocation = nil)
               # ^ error: Variable name should be underscore-cased: `@start_location`, not `@startLocation`
                                     # ^ error: Variable name should be underscore-cased: `@end_location`, not `@endLocation`
          end
        end
        CRYSTAL
    end

    it "reports class variable name" do
      expect_issue subject, <<-CRYSTAL
        class Greeting
          @@defaultGreeting = "Hello world"
        # ^^^^^^^^^^^^^^^^^ error: Variable name should be underscore-cased: `@@default_greeting`, not `@@defaultGreeting`
        end
        CRYSTAL
    end
  end
end
