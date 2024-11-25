require "../../../spec_helper"

module Ameba::Rule::Lint
  describe RequireParentheses do
    subject = RequireParentheses.new

    it "passes if logical operator in call args has parentheses" do
      expect_no_issues subject, <<-CRYSTAL
        if foo.includes?("bar") || foo.includes?("batz")
          puts "this code is bug-free"
        end

        if foo.includes?("bar" || foo.includes? "batz")
          puts "this code is bug-free"
        end

        form.add("query", "val_1" || "val_2")
        form.add "query", "val_1" || "val_2"
        form.add "query", ("val_1" || "val_2")
        CRYSTAL
    end

    it "passes if logical operator in assignment call" do
      expect_no_issues subject, <<-CRYSTAL
        hello.there = "world" || method.call
        hello.there ||= "world" || method.call
        CRYSTAL
    end

    it "passes if logical operator in square bracket call" do
      expect_no_issues subject, <<-CRYSTAL
        hello["world" || :thing]
        hello["world" || :thing]?
        this.is[1 || method.call]
        CRYSTAL
    end

    it "fails if logical operator in call args doesn't have parentheses" do
      expect_issue subject, <<-CRYSTAL
        if foo.includes? "bar" || foo.includes? "batz"
         # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use parentheses in the method call to avoid confusion about precedence
          puts "this code is not bug-free"
        end

        if foo.in? "bar", "baz" || foo.ends_with? "qux"
         # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use parentheses in the method call to avoid confusion about precedence
          puts "this code is not bug-free"
        end
        CRYSTAL
    end
  end
end
