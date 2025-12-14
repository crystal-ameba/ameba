require "../../../spec_helper"

module Ameba::Rule::Style
  describe Elsif do
    subject = Elsif.new

    it "does not report an issue for if statements" do
      expect_no_issues subject, <<-CRYSTAL
        def func
          if something
            foo
          end
        end
        CRYSTAL
    end

    it "does not report an issue for if/else statements" do
      expect_no_issues subject, <<-CRYSTAL
        def func
          if something
            foo
          else
            bar
          end
        end
        CRYSTAL
    end

    it "does not report an issue for if statements (ternary)" do
      expect_no_issues subject, <<-CRYSTAL
        def func
          something ? foo : bar
        end
        CRYSTAL
    end

    it "does not report an issue for if statements (else + ternary if)" do
      expect_no_issues subject, <<-CRYSTAL
        def func
          something ? foo : something_else ? bar : baz
        end
        CRYSTAL
    end

    it "reports an issue for if/elsif statements" do
      expect_issue subject, <<-CRYSTAL
        def func
          if something
        # ^^^^^^^^^^^^ error: Prefer `case/when` over `if/elsif`
            foo
          elsif something_else
            bar
          end
        end
        CRYSTAL
    end

    context "properties" do
      it "#allowed_branches" do
        rule = Elsif.new
        rule.max_branches = 1

        expect_no_issues rule, <<-CRYSTAL
          def func
            if something
              foo
            elsif something_else
              bar
            end
          end
          CRYSTAL

        expect_issue rule, <<-CRYSTAL
          def func
            if something
          # ^^^^^^^^^^^^ error: Prefer `case/when` over `if/elsif`
              foo
            elsif something_bar
              bar
            elsif something_baz
              baz
            end
          end
          CRYSTAL
      end
    end
  end
end
