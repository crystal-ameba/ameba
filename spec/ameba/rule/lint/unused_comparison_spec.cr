require "../../../spec_helper"

module Ameba::Rule::Lint
  describe UnusedComparison do
    subject = UnusedComparison.new

    it "passes if comparison used in assign" do
      expect_no_issues subject, <<-CRYSTAL
        foo = 1 == "1"
        bar = begin
          2 == "2"
        end
        CRYSTAL
    end

    it "passes if comparison used in if condition" do
      expect_no_issues subject, <<-CRYSTAL
        if foo == bar
          puts "baz"
        end
        CRYSTAL
    end

    it "passes if comparison implicitly returns from method body" do
      expect_no_issues subject, <<-CRYSTAL
        def foo
          1 == 2
        end
        CRYSTAL
    end

    it "passes for implicit object comparisons" do
      expect_no_issues subject, <<-CRYSTAL
        case obj
        when .> 1 then true
        when .< 0 then false
        end
        CRYSTAL
    end

    it "passes for comparisons inside '||' and '&&' where the other arg is a call" do
      expect_no_issues subject, <<-CRYSTAL
        foo(bar) == baz || raise "bat"
        foo(bar) == baz && raise "bat"
        CRYSTAL
    end

    it "passes for unused comparisons with `===`, `=~`, and `!~`" do
      expect_no_issues subject, <<-CRYSTAL
        /foo(bar)?/ =~ baz
        /foo(bar)?/ !~ baz
        "foo" === bar
        CRYSTAL
    end

    it "fails for top-level `==` operator" do
      expect_issue subject, <<-CRYSTAL
        foo == 2
        # ^^^^^^ error: Comparison operation is unused
        CRYSTAL
    end

    it "fails for top-level `!=` operator" do
      expect_issue subject, <<-CRYSTAL
        foo != 2
        # ^^^^^^ error: Comparison operation is unused
        CRYSTAL
    end

    it "fails for top-level `<` operator" do
      expect_issue subject, <<-CRYSTAL
        foo < 2
        # ^^^^^ error: Comparison operation is unused
        CRYSTAL
    end

    it "fails for top-level `<=` operator" do
      expect_issue subject, <<-CRYSTAL
        foo <= 2
        # ^^^^^^ error: Comparison operation is unused
        CRYSTAL
    end

    it "fails for top-level `>` operator" do
      expect_issue subject, <<-CRYSTAL
        foo > 2
        # ^^^^^ error: Comparison operation is unused
        CRYSTAL
    end

    it "fails for top-level `>=` operator" do
      expect_issue subject, <<-CRYSTAL
        foo >= 2
        # ^^^^^^ error: Comparison operation is unused
        CRYSTAL
    end

    it "fails for top-level `<=>` operator" do
      expect_issue subject, <<-CRYSTAL
        foo <=> 2
        # ^^^^^^^ error: Comparison operation is unused
        CRYSTAL
    end

    it "fails for an unused comparison in a begin block" do
      expect_issue subject, <<-CRYSTAL
        begin
          x = 1
          x == 2
        # ^^^^^^ error: Comparison operation is unused
          puts x
        end
        CRYSTAL
    end

    it "fails for unused comparisons in if/elsif/else bodies" do
      expect_issue subject, <<-CRYSTAL
        a = if x = 1
              x == 1
            # ^^^^^^ error: Comparison operation is unused
              x == 2
            elsif true
              x == 1
            # ^^^^^^ error: Comparison operation is unused
              x == 2
            else
              x == 2
            # ^^^^^^ error: Comparison operation is unused
              x == 3
            end
        CRYSTAL
    end

    it "fails for unused comparisons in a proc body" do
      expect_issue subject, <<-CRYSTAL
        a = -> do
          x == 1
        # ^^^^^^ error: Comparison operation is unused
          "meow"
        end
        CRYSTAL
    end

    it "fails for unused comparison in top-level if statement body" do
      expect_issue subject, <<-CRYSTAL
        if true
          x == 1
        # ^^^^^^ error: Comparison operation is unused
        else
          x == 2
        # ^^^^^^ error: Comparison operation is unused
        end
        CRYSTAL
    end

    it "fails for unused comparison in void of method body" do
      expect_issue subject, <<-CRYSTAL
        def foo
          if x == 3
            x < 1
          # ^^^^^ error: Comparison operation is unused
          else
            x > 1
          # ^^^^^ error: Comparison operation is unused
          end

          return
        end
        CRYSTAL
    end
  end
end
