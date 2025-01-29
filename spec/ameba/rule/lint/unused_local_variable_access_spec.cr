require "../../../spec_helper"

module Ameba::Rule::Lint
  describe UnusedLocalVariableAccess do
    subject = UnusedLocalVariableAccess.new

    it "passes if local variables are used" do
      expect_no_issues subject, <<-CRYSTAL
        a = 1

        puts a

        a += 1
        a, b = 2, 3
        CRYSTAL
    end

    it "passes if local variable on left side of a comparison" do
      expect_no_issues subject, <<-CRYSTAL
        def hello
          a = 1
          a || (puts "a is falsey")
          a
        end
        CRYSTAL
    end

    it "passes if skip_file exists in a macro" do
      expect_no_issues subject, <<-CRYSTAL
        {% skip_file %}
        CRYSTAL
    end

    it "fails if local variables are unused" do
      expect_issue subject, <<-CRYSTAL
        a = 1

        begin
          a
        # ^ error: Value from local variable access is unused
          puts a
        end
        CRYSTAL
    end
  end
end
