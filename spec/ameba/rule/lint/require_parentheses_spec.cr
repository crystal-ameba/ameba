require "../../../spec_helper"

module Ameba::Rule::Lint
  describe RequireParentheses do
    subject = RequireParentheses.new

    it "passes if logical operator in call args has parentheses" do
      expect_no_issues subject, <<-CRYSTAL
        foo.includes?("bar") || foo.includes?("baz")
        foo.includes?("bar" || foo.includes? "baz")
        CRYSTAL
    end

    it "passes if logical operator in call doesn't involve another method call" do
      expect_no_issues subject, <<-CRYSTAL
        foo.includes? "bar" || "baz"
        CRYSTAL
    end

    it "passes if logical operator in call involves another method call with no arguments" do
      expect_no_issues subject, <<-CRYSTAL
        foo.includes? "bar" || foo.not_nil!
        CRYSTAL
    end

    it "passes if logical operator is used in an assignment call" do
      expect_no_issues subject, <<-CRYSTAL
        foo.bar = "baz" || bat.call :foo
        foo.bar ||= "baz" || bat.call :foo
        foo[bar] = "baz" || bat.call :foo
        CRYSTAL
    end

    it "passes if logical operator is used in a square bracket call" do
      expect_no_issues subject, <<-CRYSTAL
        foo["bar" || baz.call :bat]
        foo["bar" || baz.call :bat]?
        CRYSTAL
    end

    it "fails if logical operator in call args doesn't have parentheses" do
      expect_issue subject, <<-CRYSTAL
        foo.includes? "bar" || foo.includes? "baz"
        # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use parentheses in the method call to avoid confusion about precedence

        foo.in? "bar", "baz" || foo.ends_with? "bat"
        # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use parentheses in the method call to avoid confusion about precedence
        CRYSTAL
    end
  end
end
