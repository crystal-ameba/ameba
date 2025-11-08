require "../../../spec_helper"

module Ameba::Rule::Style
  describe MultilineStringLiteral do
    subject = MultilineStringLiteral.new

    context "string literals" do
      it "doesn't report if a string is on a single line" do
        expect_no_issues subject, <<-CRYSTAL
          "foo"
          CRYSTAL
      end

      it "doesn't report if a string containing `\\n` is on a single line" do
        expect_no_issues subject, <<-'CRYSTAL'
          "\nfoo\n"
          CRYSTAL
      end

      it "doesn't report heredocs" do
        expect_no_issues subject, <<-CRYSTAL
          <<-FOO
            foo
            bar
            FOO
          CRYSTAL
      end

      it "reports if there is a multi-line string" do
        expect_issue subject, <<-CRYSTAL
          "
          # ^{} error: Use `<<-HEREDOC` markers for multiline strings
            foo
            bar
          "
          CRYSTAL
      end

      it "reports if there is a multi-line percent string: `%()`" do
        expect_issue subject, <<-CRYSTAL
          %(
          # ^{} error: Use `<<-HEREDOC` markers for multiline strings
            foo
            bar
          )
          CRYSTAL
      end

      it "reports if there is a multi-line percent string: `%q()`" do
        expect_issue subject, <<-CRYSTAL
          %q(
          # ^ error: Use `<<-HEREDOC` markers for multiline strings
            foo
            bar
          )
          CRYSTAL
      end
    end

    context "string interpolations" do
      it "doesn't report if a string is on a single line" do
        expect_no_issues subject, <<-CRYSTAL
          "#{"foo"}"
          CRYSTAL
      end

      it "doesn't report regex literals" do
        expect_no_issues subject, <<-'CRYSTAL'
          /\A#{foo}\Z/
          CRYSTAL
      end

      it "doesn't report command literals" do
        expect_no_issues subject, <<-'CRYSTAL'
          `#{foo}`
          CRYSTAL
      end

      it "doesn't report if a string containing `\\n` is on a single line" do
        expect_no_issues subject, <<-'CRYSTAL'
          "#{"\nfoo\n"}"
          CRYSTAL
      end

      it "doesn't report heredocs" do
        expect_no_issues subject, <<-CRYSTAL
          <<-FOO
            foo
            #{"bar"}
            baz
            FOO
          CRYSTAL
      end

      it "reports if there is a multi-line string" do
        expect_issue subject, <<-'CRYSTAL'
          "
          # ^{} error: Use `<<-HEREDOC` markers for multiline strings
            #{"foo"}
            bar
          "
          CRYSTAL
      end
    end

    context "properties" do
      describe "#allow_backslash_split_strings" do
        it "passes on formatter errors by default" do
          rule = MultilineStringLiteral.new

          expect_no_issues rule, <<-CRYSTAL
            "foo" \\
            "bar" \\
            "baz"
            CRYSTAL
        end

        it "reports on formatter errors when disabled" do
          rule = MultilineStringLiteral.new
          rule.allow_backslash_split_strings = false

          expect_issue rule, <<-CRYSTAL
            "foo" \\
            # ^^^^^ error: Use `<<-HEREDOC` markers for multiline strings
            "bar" \\
            "baz"
            CRYSTAL
        end
      end
    end
  end
end
