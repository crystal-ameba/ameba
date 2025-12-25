require "../../../spec_helper"

module Ameba::Rule::Style
  describe CallParentheses do
    subject = CallParentheses.new

    it "passes for valid method calls" do
      expect_no_issues subject, <<-CRYSTAL
        foo
        foo.bar?
        foo[0] = bar
        foo.bar = baz
        foo + bar
        CRYSTAL
    end

    it "passes if method call has parentheses" do
      expect_no_issues subject, <<-CRYSTAL
        foo(bar: 1)
        CRYSTAL
    end

    it "fails for method call without parentheses with positional arguments" do
      source = expect_issue subject, <<-CRYSTAL
        foo bar
        # ^^^^^ error: Missing parentheses in method call
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(bar)
        CRYSTAL
    end

    it "fails for method call without parentheses with named arguments" do
      source = expect_issue subject, <<-CRYSTAL
        foo bar: 1
        # ^^^^^^^^ error: Missing parentheses in method call
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(bar: 1)
        CRYSTAL
    end

    it "fails for method call without parentheses with positional + named arguments" do
      source = expect_issue subject, <<-CRYSTAL
        foo bar, baz: 1
        # ^^^^^^^^^^^^^ error: Missing parentheses in method call
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(bar, baz: 1)
        CRYSTAL
    end

    it "fails for method call without parentheses with positional + named arguments" do
      source = expect_issue subject, <<-CRYSTAL
        bats = bats [Bat.new path: "bat.cr"]
        # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Missing parentheses in method call
                   # ^^^^^^^^^^^^^^^^^^^^^^ error: Missing parentheses in method call
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        bats = bats([Bat.new(path: "bat.cr")])
        CRYSTAL
    end

    it "fails for method call without parentheses with positional + named arguments" do
      source = expect_issue subject, <<-CRYSTAL
        foo bar, baz: baz if baz.fooable?
        # ^^^^^^^^^^^^^^^ error: Missing parentheses in method call
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(bar, baz: baz) if baz.fooable?
        CRYSTAL
    end

    it "fails for method call without parentheses with block arg" do
      source = expect_issue subject, <<-CRYSTAL
        foo bar: 1, &proc
        # ^^^^^^^^^^^^^^^ error: Missing parentheses in method call
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(bar: 1, &proc)
        CRYSTAL
    end

    it "fails for method call without parentheses with block" do
      source = expect_issue subject, <<-CRYSTAL
        foo bar: 1 do |x, y|
        # ^^^^^^^^^^^^^^^^^^ error: Missing parentheses in method call
          baz(x, y)
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(bar: 1) do |x, y|
          baz(x, y)
        end
        CRYSTAL
    end

    it "fails for method call without parentheses with block (single line)" do
      source = expect_issue subject, <<-CRYSTAL
        foo bar: 1 { |x, y| baz(x, y) }
        # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Missing parentheses in method call
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(bar: 1) { |x, y| baz(x, y) }
        CRYSTAL
    end

    it "fails for method call without parentheses with block (short)" do
      source = expect_issue subject, <<-CRYSTAL
        foo bar: 1, &.baz?
        # ^^^^^^^^^^^^^^^^ error: Missing parentheses in method call
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(bar: 1, &.baz?)
        CRYSTAL
    end

    it "fails for method call without parentheses with heredoc argument" do
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

    it "fails for method call without parentheses with multiple heredoc arguments" do
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

    it "fails for method call without parentheses with named + heredoc argument" do
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

    it "fails for method call without parentheses with named + heredoc argument" do
      source = expect_issue subject, <<-CRYSTAL
        foo.should eq <<-HEREDOC
                 # ^^^^^^^^^^^^^ error: Missing parentheses in method call
          HEREDOC
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo.should eq(<<-HEREDOC)
          HEREDOC
        CRYSTAL
    end
  end
end
