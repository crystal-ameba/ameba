require "../../../spec_helper"

module Ameba::Rule::Lint
  describe TrailingCommaInMultilineArgument do
    subject = TrailingCommaInMultilineArgument.new

    it "passes for single line calls" do
      expect_no_issues subject, <<-CRYSTAL
        foo(bar, baz)
        foo(bar: baz)
        foo(bar, baz: "qux")
        CRYSTAL
    end

    it "reports when nothing follows a single argument" do
      source = expect_issue subject, <<-CRYSTAL
        foo(
          bar
        # ^^^ error: Missing trailing comma after the last call argument
        )
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(
          bar,
        )
        CRYSTAL
    end

    it "passes for trailing comma after a single argument" do
      expect_no_issues subject, <<-CRYSTAL
        foo(
          bar,
        )
        CRYSTAL
    end

    it "reports when nothing follows the last argument" do
      source = expect_issue subject, <<-CRYSTAL
        foo(
          bar,
          baz
        # ^^^ error: Missing trailing comma after the last call argument
        )
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(
          bar,
          baz,
        )
        CRYSTAL
    end

    it "passes for trailing comma after the last argument" do
      expect_no_issues subject, <<-CRYSTAL
        foo(
          bar,
          baz,
        )
        CRYSTAL
    end

    it "reports when nothing follows the last named argument" do
      source = expect_issue subject, <<-CRYSTAL
        foo(
          bar: 1,
          baz: 2
        # ^^^^^^ error: Missing trailing comma after the last call argument
        )
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(
          bar: 1,
          baz: 2,
        )
        CRYSTAL
    end

    it "reports when nothing follows the last named argument" do
      source = expect_issue subject, <<-CRYSTAL
        foo("foo", "bar",
          named: value
        # ^^^^^^^^^^^^ error: Missing trailing comma after the last call argument
        )
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo("foo", "bar",
          named: value,
        )
        CRYSTAL
    end

    it "passes for trailing comma after the last named argument" do
      expect_no_issues subject, <<-CRYSTAL
        foo("foo", "bar",
          named: value,
        )
        CRYSTAL
    end

    it "reports when nothing follows the last argument" do
      source = expect_issue subject, <<-CRYSTAL
        foo(
          bar,
          if baz
        # ^^^^^^ error: Missing trailing comma after the last call argument
            1
          else
            2
          end
        )
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(
          bar,
          if baz
            1
          else
            2
          end,
        )
        CRYSTAL
    end

    it "allows a trailing comma after the last argument" do
      expect_no_issues subject, <<-CRYSTAL
        foo(
          bar,
          if baz
            1
          else
            2
          end,
        )
        CRYSTAL
    end

    it "passes for non-parenthesized calls" do
      expect_no_issues subject, <<-CRYSTAL
        foo bar,
          baz: 1,
          qux: 2
        CRYSTAL
    end

    it "passes for arguments where the last is a heredoc" do
      expect_no_issues subject, <<-CRYSTAL
        foo(
          bar,
          baz: <<-HEREDOC
            qux
            HEREDOC
        )
        CRYSTAL
    end
  end
end
