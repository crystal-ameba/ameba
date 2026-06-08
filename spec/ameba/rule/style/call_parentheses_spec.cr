require "../../../spec_helper"

module Ameba::Rule::Style
  describe CallParentheses do
    subject = CallParentheses.new
    subject.exclude_multiline_calls = false
    subject.exclude_type_declarations = false
    subject.exclude_heredocs = false

    it "ignores ECR files" do
      expect_no_issues subject, <<-ECR, path: "foo.ecr"
        <%= foo bar %>
        ECR
    end

    it "passes for valid method calls" do
      expect_no_issues subject, <<-CRYSTAL
        foo
        foo.bar?
        foo[0] = bar
        foo.bar = baz
        foo + bar
        foo.+ bar
        foo.bar(&.== baz)
        CRYSTAL
    end

    it "passes if method call has parentheses" do
      expect_no_issues subject, <<-CRYSTAL
        foo(bar: 1)
        CRYSTAL
    end

    it "fails for method call with positional arguments" do
      source = expect_issue subject, <<-CRYSTAL
        foo bar
        # ^^^^^ error: Missing parentheses in method call
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(bar)
        CRYSTAL
    end

    it "fails for method call with named arguments" do
      source = expect_issue subject, <<-CRYSTAL
        foo bar: 1
        # ^^^^^^^^ error: Missing parentheses in method call
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(bar: 1)
        CRYSTAL
    end

    it "fails for nested method call with named arguments" do
      source = expect_issue subject, <<-CRYSTAL
        foo(bar path: "bar.cr")
          # ^^^^^^^^^^^^^^^^^^ error: Missing parentheses in method call
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(bar(path: "bar.cr"))
        CRYSTAL
    end

    it "fails for method call with positional + named arguments" do
      source = expect_issue subject, <<-CRYSTAL
        foo bar, baz: 1
        # ^^^^^^^^^^^^^ error: Missing parentheses in method call
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(bar, baz: 1)
        CRYSTAL
    end

    it "fails for method call with positional + named arguments" do
      source = expect_issue subject, <<-CRYSTAL
        bats = bats [Bat.new path: "bat.cr"]
             # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Missing parentheses in method call
                   # ^^^^^^^^^^^^^^^^^^^^^^ error: Missing parentheses in method call
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        bats = bats([Bat.new(path: "bat.cr")])
        CRYSTAL
    end

    it "fails for method call with positional + named arguments" do
      source = expect_issue subject, <<-CRYSTAL
        foo bar, baz: baz if baz.fooable?
        # ^^^^^^^^^^^^^^^ error: Missing parentheses in method call
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(bar, baz: baz) if baz.fooable?
        CRYSTAL
    end

    it "fails for method call with block arg" do
      source = expect_issue subject, <<-CRYSTAL
        foo &proc
        # ^^^^^^^ error: Missing parentheses in method call
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(&proc)
        CRYSTAL
    end

    it "fails for method call with block (short)" do
      source = expect_issue subject, <<-CRYSTAL
        foo &.baz?
        # ^^^^^^^^ error: Missing parentheses in method call
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(&.baz?)
        CRYSTAL
    end

    it "fails for method call with block (short)" do
      source = expect_issue subject, <<-CRYSTAL
        foo &.[baz]?
        # ^^^^^^^^^^ error: Missing parentheses in method call
        foo &.[baz]
        # ^^^^^^^^^ error: Missing parentheses in method call
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(&.[baz]?)
        foo(&.[baz])
        CRYSTAL
    end

    it "fails for method call with square bracket call as argument" do
      source = expect_issue subject, <<-CRYSTAL
        io.write prefix[0, total.clamp(..prefix.bytesize)]
        # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Missing parentheses in method call
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        io.write(prefix[0, total.clamp(..prefix.bytesize)])
        CRYSTAL
    end

    it "fails for method call with block (short) + parenthesized inner call with named arguments" do
      source = expect_issue subject, <<-CRYSTAL
        Log.debug &.emit("Fox",
        # ^^^^^^^^^^^^^^^^^^^^^ error: Missing parentheses in method call
          foo: "foo",
          bar: "bar",
        )
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        Log.debug(&.emit("Fox",
          foo: "foo",
          bar: "bar",
        ))
        CRYSTAL
    end

    it "fails for method call with block (short) + inner call with block" do
      source = expect_issue subject, <<-CRYSTAL
        foo &.map { |x| x }
        # ^^^^^^^^^^^^^^^^^ error: Missing parentheses in method call
        foo &.map do |x|
        # ^^^^^^^^^^^^^^ error: Missing parentheses in method call
          x
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(&.map { |x| x })
        foo(&.map do |x|
          x
        end)
        CRYSTAL
    end

    it "fails for method call with block (short) + inner call with heredoc argument" do
      source = expect_issue subject, <<-CRYSTAL
        foo &.bar <<-FOO
        # ^^^^^^^^^^^^^^ error: Missing parentheses in method call
            # ^^^^^^^^^^ error: Missing parentheses in method call
          fox
          FOO
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(&.bar(<<-FOO))
          fox
          FOO
        CRYSTAL
    end

    it "fails for method call with block (short) + inner setter" do
      source = expect_issue subject, <<-CRYSTAL
        foo &.bar = baz
        # ^^^^^^^^^^^^^ error: Missing parentheses in method call
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(&.bar = baz)
        CRYSTAL
    end

    it "fails for method call with block (short) + inner setter with heredoc argument" do
      source = expect_issue subject, <<-CRYSTAL
        foo &.bar = <<-FOO
        # ^^^^^^^^^^^^^^^^ error: Missing parentheses in method call
          fox
          FOO
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(&.bar = <<-FOO)
          fox
          FOO
        CRYSTAL
    end

    it "fails for method call with block (short) + inner bracket setter" do
      source = expect_issue subject, <<-CRYSTAL
        foo &.[bar] = baz
        # ^^^^^^^^^^^^^^^ error: Missing parentheses in method call
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(&.[bar] = baz)
        CRYSTAL
    end

    it "fails for method call with block (short) + inner bracket setter with heredoc argument" do
      source = expect_issue subject, <<-CRYSTAL
        foo &.[bar] = <<-FOO
        # ^^^^^^^^^^^^^^^^^^ error: Missing parentheses in method call
          fox
          FOO
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(&.[bar] = <<-FOO)
          fox
          FOO
        CRYSTAL
    end

    it "fails for method call with block" do
      source = expect_issue subject, <<-CRYSTAL
        foo bar: 1 do |x, y|
        # ^^^^^^^^ error: Missing parentheses in method call
          baz(x, y)
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(bar: 1) do |x, y|
          baz(x, y)
        end
        CRYSTAL
    end

    it "fails for method call with block (single line)" do
      source = expect_issue subject, <<-CRYSTAL
        foo bar: 1 { |x, y| baz(x, y) }
        # ^^^^^^^^ error: Missing parentheses in method call
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(bar: 1) { |x, y| baz(x, y) }
        CRYSTAL
    end

    it "fails for method call with heredoc argument" do
      source = expect_issue subject, <<-CRYSTAL
        foo <<-HEREDOC
        # ^^^^^^^^^^^^ error: Missing parentheses in method call
          HEREDOC
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(<<-HEREDOC)
          HEREDOC
        CRYSTAL
    end

    it "fails for method call with multiple heredoc arguments" do
      source = expect_issue subject, <<-CRYSTAL
        foo <<-FOO, <<-BAR
        # ^^^^^^^^^^^^^^^^ error: Missing parentheses in method call
          FOO
          BAR
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(<<-FOO, <<-BAR)
          FOO
          BAR
        CRYSTAL
    end

    it "fails for method call with heredoc named argument" do
      source = expect_issue subject, <<-CRYSTAL
        foo 123,
        # ^^^^^^ error: Missing parentheses in method call
          bar: <<-HEREDOC,
            bar
            HEREDOC
          baz: <<-HEREDOC
            baz
            HEREDOC
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(123,
          bar: <<-HEREDOC,
            bar
            HEREDOC
          baz: <<-HEREDOC)
            baz
            HEREDOC
        CRYSTAL
    end

    it "removes stray backslash from the end of a first line" do
      source = expect_issue subject, <<-CRYSTAL
        foo \\
        # ^^^ error: Missing parentheses in method call
          bar: 1,
          baz: 2
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(
          bar: 1,
          baz: 2)
        CRYSTAL
    end

    it "fails for method call with named + heredoc argument" do
      source = expect_issue subject, <<-CRYSTAL
        foo <<-HEREDOC, bar: 42
        # ^^^^^^^^^^^^^^^^^^^^^ error: Missing parentheses in method call
          HEREDOC
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(<<-HEREDOC, bar: 42)
          HEREDOC
        CRYSTAL
    end

    it "fails for method call with heredoc argument + more arguments following" do
      source = expect_issue subject, <<-CRYSTAL
        foo <<-HEREDOC,
        # ^^^^^^^^^^^^^ error: Missing parentheses in method call
          foo
          HEREDOC
          "bar"
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(<<-HEREDOC,
          foo
          HEREDOC
          "bar")
        CRYSTAL
    end

    context "properties" do
      context "#exclude_multiline_calls" do
        it "ignores multiline calls when enabled" do
          rule = CallParentheses.new
          rule.exclude_multiline_calls = true

          expect_no_issues rule, <<-CRYSTAL
            foo 42,
              bar: "baz"
            CRYSTAL
        end

        it "reports multiline calls when disabled" do
          rule = CallParentheses.new
          rule.exclude_multiline_calls = false

          source = expect_issue rule, <<-CRYSTAL
            foo 42,
            # ^^^^^ error: Missing parentheses in method call
              bar: "baz"
            CRYSTAL

          expect_correction source, <<-CRYSTAL
            foo(42,
              bar: "baz")
            CRYSTAL
        end
      end

      context "#excluded_dsl_call_names" do
        it "passes for given call paths (at toplevel namespace)" do
          rule = CallParentheses.new
          rule.excluded_dsl_call_names = [
            "foo > *",
            "foo > fox > *",
            "bat > **",
          ]
          expect_no_issues rule, <<-CRYSTAL
            foo { bar 369 }
            foo do
              bar 369.times { |i| bat i }
              baz :qux
              fox do
                name "Fawny Fox"
                home "Dry Den"
              end
            end
            bat do
              qux 123 do
                bar :bar
              end
            end
            CRYSTAL
        end

        it "passes for given call paths (within a class)" do
          rule = CallParentheses.new
          rule.excluded_dsl_call_names = [
            "Foo > foo > *",
            "Foo > foo > fox > *",
            "Foo > bat > **",
          ]
          expect_no_issues rule, <<-CRYSTAL
            class Foo
              foo { bar 369 }
              foo do
                bar 369.times { |i| bat i }
                baz :qux
                fox do
                  name "Fawny Fox"
                  home "Dry Den"
                end
              end
              bat do
                qux 123 do
                  bar :bar
                end
              end
            end
            CRYSTAL
        end

        it "reports outer calls regardless of dsl calls (within a class)" do
          rule = CallParentheses.new
          rule.excluded_dsl_call_names = [
            "Foo > foo > *",
          ]
          source = expect_issue rule, <<-CRYSTAL
            class Foo
              foo bar 369
            # ^^^^^^^^^^^ error: Missing parentheses in method call
                # ^^^^^^^ error: Missing parentheses in method call
            end
            CRYSTAL

          expect_correction source, <<-CRYSTAL
            class Foo
              foo(bar(369))
            end
            CRYSTAL
        end

        it "reports outer calls regardless of dsl calls (at toplevel namespace)" do
          rule = CallParentheses.new
          rule.excluded_dsl_call_names = [
            "foo > *",
          ]
          source = expect_issue rule, <<-CRYSTAL
            foo bar 369
            # ^^^^^^^^^ error: Missing parentheses in method call
              # ^^^^^^^ error: Missing parentheses in method call
            CRYSTAL

          expect_correction source, <<-CRYSTAL
            foo(bar(369))
            CRYSTAL
        end
      end

      context "#exclude_type_declarations" do
        it "ignores type declarations when enabled" do
          rule = CallParentheses.new
          rule.exclude_type_declarations = true

          expect_no_issues rule, <<-CRYSTAL
            foo bar : Symbol
            CRYSTAL
        end

        it "reports type declarations when disabled" do
          rule = CallParentheses.new
          rule.exclude_type_declarations = false

          source = expect_issue rule, <<-CRYSTAL
            foo bar : Symbol
            # ^^^^^^^^^^^^^^ error: Missing parentheses in method call
            CRYSTAL

          expect_correction source, <<-CRYSTAL
            foo(bar : Symbol)
            CRYSTAL
        end
      end

      context "#exclude_heredocs" do
        it "ignores calls with heredoc arguments when enabled" do
          rule = CallParentheses.new
          rule.exclude_heredocs = true

          expect_no_issues rule, <<-CRYSTAL
            foo bar : Symbol
            CRYSTAL
        end

        it "reports calls with heredoc arguments when disabled" do
          rule = CallParentheses.new
          rule.exclude_heredocs = false

          source = expect_issue rule, <<-CRYSTAL
            foo.bar <<-HEREDOC
            # ^^^^^^^^^^^^^^^^ error: Missing parentheses in method call
              HEREDOC
            CRYSTAL

          expect_correction source, <<-CRYSTAL
            foo.bar(<<-HEREDOC)
              HEREDOC
            CRYSTAL
        end
      end

      context "#excluded_toplevel_call_names" do
        it "ignores top level calls" do
          rule = CallParentheses.new
          rule.excluded_toplevel_call_names = %w[foo bar]

          expect_no_issues rule, <<-CRYSTAL
            foo bar
            bar baz
            CRYSTAL

          expect_issue rule, <<-CRYSTAL
            foo.bar baz
            # ^^^^^^^^^ error: Missing parentheses in method call
            CRYSTAL
        end
      end

      context "#excluded_call_names" do
        it "ignores non-top level calls" do
          rule = CallParentheses.new
          rule.excluded_call_names = %w[foo bar]

          expect_no_issues rule, <<-CRYSTAL
            foo.bar baz
            bar.foo baz
            CRYSTAL

          expect_issue rule, <<-CRYSTAL
            foo bar
            # ^^^^^ error: Missing parentheses in method call
            CRYSTAL
        end
      end
    end
  end
end
