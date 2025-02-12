require "../../../spec_helper"

module Ameba::Rule::Lint
  describe UnusedLocalVariableAccess do
    subject = UnusedLocalVariableAccess.new

    it "passes if local variables are used in assign" do
      expect_no_issues subject, <<-CRYSTAL
        a = 1
        a += 1
        a, b = 2, 3
        CRYSTAL
    end

    it "passes if a local variable is a call argument" do
      expect_no_issues subject, <<-CRYSTAL
        a = 1
        puts a
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

    it "passes if skip_file is used in a macro" do
      expect_no_issues subject, <<-CRYSTAL
        {% skip_file %}
        CRYSTAL
    end

    it "passes if debug is used in a macro" do
      expect_no_issues subject, <<-CRYSTAL
        {% debug %}
        CRYSTAL
    end

    it "fails if a local variable is in a void context" do
      expect_issue subject, <<-CRYSTAL
        a = 1

        begin
          a
        # ^ error: Value from local variable access is unused
          puts a
        end
        CRYSTAL
    end

    it "fails if a parameter is in a void context" do
      expect_issue subject, <<-CRYSTAL
        def foo(bar)
          if bar > 0
            bar
          # ^^^ error: Value from local variable access is unused
          end

          nil
        end
        CRYSTAL
    end
  end
end
