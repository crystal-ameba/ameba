require "../../../spec_helper"

module Ameba
  subject = Rule::Style::GuardClause.new

  private def it_reports_body(body, *, file = __FILE__, line = __LINE__)
    rule = Rule::Style::GuardClause.new

    it "reports an issue if method body is if / unless without else", file, line do
      source = expect_issue rule, <<-CRYSTAL, file: file, line: line
        def func
          if something
        # ^^ error: Use a guard clause (`return unless something`) instead of wrapping the code inside a conditional expression.
            #{body}
          end
        end

        def func
          unless something
        # ^^^^^^ error: Use a guard clause (`return if something`) instead of wrapping the code inside a conditional expression.
            #{body}
          end
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL, file: file, line: line
        def func
          return unless something
            #{body}
         #{trailing_whitespace}
        end

        def func
          return if something
            #{body}
         #{trailing_whitespace}
        end
        CRYSTAL
    end

    it "reports an issue if method body ends with if / unless without else", file, line do
      source = expect_issue rule, <<-CRYSTAL, file: file, line: line
        def func
          test
          if something
        # ^^ error: Use a guard clause (`return unless something`) instead of wrapping the code inside a conditional expression.
            #{body}
          end
        end

        def func
          test
          unless something
        # ^^^^^^ error: Use a guard clause (`return if something`) instead of wrapping the code inside a conditional expression.
            #{body}
          end
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL, file: file, line: line
        def func
          test
          return unless something
            #{body}
         #{trailing_whitespace}
        end

        def func
          test
          return if something
            #{body}
         #{trailing_whitespace}
        end
        CRYSTAL
    end
  end

  private def it_reports_control_expression(kw, *, file = __FILE__, line = __LINE__)
    rule = Rule::Style::GuardClause.new

    it "reports an issue with #{kw} in the if branch", file, line do
      source = expect_issue rule, <<-CRYSTAL, file: file, line: line
        def func
          if something
        # ^^ error: Use a guard clause (`#{kw} if something`) instead of wrapping the code inside a conditional expression.
            #{kw}
          else
            puts "hello"
          end
        end
        CRYSTAL

      expect_no_corrections source, file: file, line: line
    end

    it "reports an issue with #{kw} in the else branch", file, line do
      source = expect_issue rule, <<-CRYSTAL, file: file, line: line
        def func
          if something
        # ^^ error: Use a guard clause (`#{kw} unless something`) instead of wrapping the code inside a conditional expression.
          puts "hello"
          else
            #{kw}
          end
        end
        CRYSTAL

      expect_no_corrections source, file: file, line: line
    end

    it "doesn't report an issue if condition has multiple lines", file, line do
      expect_no_issues rule, <<-CRYSTAL, file: file, line: line
        def func
          if something &&
               something_else
            #{kw}
          else
            puts "hello"
          end
        end
        CRYSTAL
    end

    it "does not report an issue if #{kw} is inside elsif", file, line do
      expect_no_issues rule, <<-CRYSTAL, file: file, line: line
        def func
          if something
            a
          elsif something_else
            #{kw}
          end
        end
        CRYSTAL
    end

    it "does not report an issue if #{kw} is inside if..elsif..else..end", file, line do
      expect_no_issues rule, <<-CRYSTAL, file: file, line: line
        def func
          if something
            a
          elsif something_else
            b
          else
            #{kw}
          end
        end
        CRYSTAL
    end

    it "doesn't report an issue if control flow expr has multiple lines", file, line do
      expect_no_issues rule, <<-CRYSTAL, file: file, line: line
        def func
          if something
            #{kw} \\
                  "blah blah blah" \\
                  "blah blah blah"
          else
            puts "hello"
          end
        end
        CRYSTAL
    end

    it "reports an issue if non-control-flow branch has multiple lines", file, line do
      source = expect_issue rule, <<-CRYSTAL, file: file, line: line
        def func
          if something
        # ^^ error: Use a guard clause (`#{kw} if something`) instead of wrapping the code inside a conditional expression.
            #{kw}
          else
            puts "hello" \\
                 "blah blah blah"
          end
        end
        CRYSTAL

      expect_no_corrections source, file: file, line: line
    end
  end

  describe Rule::Style::GuardClause do
    it_reports_body "work"
    it_reports_body "# TODO"

    pending "does not report an issue if `else` branch is present but empty" do
      expect_no_issues subject, <<-CRYSTAL
        def method
          if bar = foo
            puts bar
          else
            # nothing
          end
        end
        CRYSTAL
    end

    it "does not report an issue if body is if..elsif..end" do
      expect_no_issues subject, <<-CRYSTAL
        def func
          if something
            a
          elsif something_else
            b
          end
        end
        CRYSTAL
    end

    it "doesn't report an issue if condition has multiple lines" do
      expect_no_issues subject, <<-CRYSTAL
        def func
          if something &&
               something_else
            work
          end
        end

        def func
          unless something &&
                   something_else
            work
          end
        end
        CRYSTAL
    end

    it "accepts a method body that is if / unless with else" do
      expect_no_issues subject, <<-CRYSTAL
        def func
          if something
            work
          else
            test
          end
        end

        def func
          unless something
            work
          else
            test
          end
        end
        CRYSTAL
    end

    it "reports an issue when using `|| raise` in `then` branch" do
      source = expect_issue subject, <<-CRYSTAL
        def func
          if something
        # ^^ error: Use a guard clause (`work || raise("message") if something`) instead of [...]
            work || raise("message")
          else
            test
          end
        end
        CRYSTAL

      expect_no_corrections source
    end

    it "reports an issue when using `|| raise` in `else` branch" do
      source = expect_issue subject, <<-CRYSTAL
        def func
          if something
        # ^^ error: Use a guard clause (`test || raise("message") unless something`) instead of [...]
            work
          else
            test || raise("message")
          end
        end
        CRYSTAL

      expect_no_corrections source
    end

    it "reports an issue when using `&& return` in `then` branch" do
      source = expect_issue subject, <<-CRYSTAL
        def func
          if something
        # ^^ error: Use a guard clause (`work && return if something`) instead of wrapping the code inside a conditional expression.
            work && return
          else
            test
          end
        end
        CRYSTAL

      expect_no_corrections source
    end

    it "reports an issue when using `&& return` in `else` branch" do
      source = expect_issue subject, <<-CRYSTAL
        def func
          if something
        # ^^ error: Use a guard clause (`test && return unless something`) instead of wrapping the code inside a conditional expression.
            work
          else
            test && return
          end
        end
        CRYSTAL

      expect_no_corrections source
    end

    it "accepts a method body that does not end with if / unless" do
      expect_no_issues subject, <<-CRYSTAL
        def func
          if something
            work
          end
          test
        end

        def func
          unless something
            work
          end
          test
        end
        CRYSTAL
    end

    it "accepts a method body that is a modifier if / unless" do
      expect_no_issues subject, <<-CRYSTAL
        def func
          work if something
        end

        def func
          work unless something
        end
        CRYSTAL
    end

    it "accepts a method with empty parentheses as its body" do
      expect_no_issues subject, <<-CRYSTAL
        def func
          ()
        end
        CRYSTAL
    end

    it "does not report an issue when assigning the result of a guard condition with `else`" do
      expect_no_issues subject, <<-CRYSTAL
        def func
          result =
            if something
              work || raise("message")
            else
              test
            end
        end
        CRYSTAL
    end

    it_reports_control_expression "return"
    it_reports_control_expression "next"
    it_reports_control_expression "break"
    it_reports_control_expression %(raise "error")

    context "method in module" do
      it "reports an issue for instance method" do
        source = expect_issue subject, <<-CRYSTAL
          module CopTest
            def test
              if something
            # ^^ error: Use a guard clause (`return unless something`) instead of wrapping the code inside a conditional expression.
                work
              end
            end
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          module CopTest
            def test
              return unless something
                work
             #{trailing_whitespace}
            end
          end
          CRYSTAL
      end

      it "reports an issue for singleton methods" do
        source = expect_issue subject, <<-CRYSTAL
          module CopTest
            def self.test
              if something && something_else
            # ^^ error: Use a guard clause (`return unless something && something_else`) instead of [...]
                work
              end
            end
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          module CopTest
            def self.test
              return unless something && something_else
                work
             #{trailing_whitespace}
            end
          end
          CRYSTAL
      end
    end
  end
end
