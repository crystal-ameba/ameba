require "../../../spec_helper"

module Ameba::Rule::Style
  subject = ParenthesesAroundCondition.new

  describe ParenthesesAroundCondition do
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
        it "skips ternary control expressions by default" do
          expect_no_issues subject, <<-CRYSTAL
            (foo > bar) ? true : false
            CRYSTAL
        end

        it "allows to configure assignments" do
          rule = ParenthesesAroundCondition.new
          rule.exclude_ternary = false

          expect_issue rule, <<-CRYSTAL
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

          expect_issue rule, <<-CRYSTAL
            if foo = @foo
             # ^^^^^^^^^^ error: Missing parentheses
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
