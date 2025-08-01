require "../../../spec_helper"

module Ameba::Rule::Style
  describe ParenthesesAroundCondition do
    subject = ParenthesesAroundCondition.new

    {% for keyword in %w[if unless while until] %}
      context "{{ keyword.id }}" do
        it "reports if redundant parentheses are found" do
          source = expect_issue subject, <<-CRYSTAL, keyword: {{ keyword }}
            %{keyword}   (foo > 10)
            _{keyword} # ^^^^^^^^^^ error: Redundant parentheses
              foo
            end
            CRYSTAL

          expect_correction source, <<-CRYSTAL
            {{ keyword.id }}   foo > 10
              foo
            end
            CRYSTAL
        end
      end
    {% end %}

    {% for keyword in %w[if unless].map(&.id) %}
      context "{{ keyword }}" do
        it "ignores expressions with `rescue`" do
          expect_no_issues subject, <<-CRYSTAL
            {{ keyword }} (foo rescue nil)
              foo
            end
            CRYSTAL
        end

        it "ignores postfix expressions with `rescue`" do
          expect_no_issues subject, <<-CRYSTAL
            foo {{ keyword }} (foo rescue nil)
            CRYSTAL
        end

        it "ignores expressions with `ensure`" do
          expect_no_issues subject, <<-CRYSTAL
            {{ keyword }} (foo ensure bar)
              foo
            end
            CRYSTAL
        end

        it "ignores postfix expressions with `ensure`" do
          expect_no_issues subject, <<-CRYSTAL
            foo {{ keyword }} (foo ensure bar)
            CRYSTAL
        end

        it "ignores expressions with `if`" do
          expect_no_issues subject, <<-CRYSTAL
            {{ keyword }} (foo if bar)
              foo
            end
            CRYSTAL
        end

        it "ignores postfix expressions with `if`" do
          expect_no_issues subject, <<-CRYSTAL
            foo {{ keyword }} (foo if bar)
            CRYSTAL
        end

        it "ignores expressions with `unless`" do
          expect_no_issues subject, <<-CRYSTAL
            {{ keyword }} (foo unless bar)
              foo
            end
            CRYSTAL
        end

        it "ignores postfix expressions with `unless`" do
          expect_no_issues subject, <<-CRYSTAL
            foo {{ keyword }} (foo unless bar)
            CRYSTAL
        end
      end
    {% end %}

    context "case" do
      it "reports if redundant parentheses are found" do
        source = expect_issue subject, <<-CRYSTAL
          case (foo = @foo)
             # ^^^^^^^^^^^^ error: Redundant parentheses
          when String then "string"
          when Symbol then "symbol"
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          case foo = @foo
          when String then "string"
          when Symbol then "symbol"
          end
          CRYSTAL
      end
    end

    context "properties" do
      context "#exclude_ternary" do
        it "reports ternary control expressions by default" do
          expect_issue subject, <<-CRYSTAL
            (foo.empty?) ? true : false
            # ^^^^^^^^^^ error: Redundant parentheses
            CRYSTAL

          expect_no_issues subject, <<-CRYSTAL
            (foo && bar) ? true : false
            (foo || bar) ? true : false
            (foo = @foo) ? true : false
            foo == 42 ? true : false
            (foo = 42) ? true : false
            (foo > 42) ? true : false
            (foo >= 42) ? true : false
            (3 >= foo >= 42) ? true : false
            (3.in? 0..42) ? true : false
            (yield 42) ? true : false
            (foo rescue 42) ? true : false
            CRYSTAL
        end

        it "allows to skip ternary control expressions" do
          rule = ParenthesesAroundCondition.new
          rule.exclude_ternary = true

          expect_no_issues rule, <<-CRYSTAL
            (foo.empty?) ? true : false
            CRYSTAL
        end
      end

      context "#exclude_multiline" do
        it "reports multiline expressions by default" do
          expect_issue subject, <<-CRYSTAL
            if (
             # ^ error: Redundant parentheses
                foo.empty? ||
                bar.empty?
              )
              baz
            end
            CRYSTAL
        end

        it "allows to skip multiline expressions" do
          rule = ParenthesesAroundCondition.new
          rule.exclude_multiline = true

          expect_no_issues rule, <<-CRYSTAL
            if (
                foo.empty? ||
                bar.empty?
              )
              baz
            end
            CRYSTAL
        end
      end

      context "#allow_safe_assignment" do
        it "reports assignments by default" do
          expect_issue subject, <<-CRYSTAL
            if (foo = @foo)
             # ^^^^^^^^^^^^ error: Redundant parentheses
              foo
            end
            CRYSTAL

          expect_no_issues subject, <<-CRYSTAL
            if !(foo = @foo)
              foo
            end
            CRYSTAL

          expect_no_issues subject, <<-CRYSTAL
            if foo = @foo
              foo
            end
            CRYSTAL
        end

        it "allows to configure assignments" do
          rule = ParenthesesAroundCondition.new
          rule.allow_safe_assignment = true

          source = expect_issue rule, <<-CRYSTAL
            if foo = @foo
             # ^^^^^^^^^^ error: Missing parentheses
              foo
            end
            CRYSTAL

          expect_correction source, <<-CRYSTAL
            if (foo = @foo)
              foo
            end
            CRYSTAL

          expect_no_issues rule, <<-CRYSTAL
            if (foo = @foo)
              foo
            end
            CRYSTAL
        end
      end
    end
  end
end
