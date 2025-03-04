require "../../../spec_helper"

module Ameba::Rule::Lint
  describe DuplicateBranch do
    subject = DuplicateBranch.new

    it "does not report different `if` and `else` branch bodies" do
      expect_no_issues subject, <<-CRYSTAL
        if :foo
          1
        elsif :foo
          2
        elsif :foo
          3
        else
          nil
        end
        CRYSTAL
    end

    it "reports duplicated `if` and `else` branch bodies" do
      expect_issue subject, <<-CRYSTAL
        if 1
          :foo
        elsif 2
          :foo
        # ^^^^ error: Duplicate branch body detected
        elsif 3
          :foo
        # ^^^^ error: Duplicate branch body detected
        else
          :foo
        # ^^^^ error: Duplicate branch body detected
        end
        CRYSTAL
    end

    it "reports duplicated `if` branch bodies" do
      expect_issue subject, <<-CRYSTAL
        if true
          :foo
        elsif false
          :foo
        # ^^^^ error: Duplicate branch body detected
        end
        CRYSTAL
    end

    it "reports duplicated `else` branch bodies" do
      expect_issue subject, <<-CRYSTAL
        if true
          :foo
        else
          :foo
        # ^^^^ error: Duplicate branch body detected
        end
        CRYSTAL
    end

    it "reports duplicated `else` branch body within `unless`" do
      expect_issue subject, <<-CRYSTAL
        unless true
          :foo
        else
          :foo
        # ^^^^ error: Duplicate branch body detected
        end
        CRYSTAL
    end

    it "reports duplicated `if` / `else` branch bodies nested within `if`" do
      expect_issue subject, <<-CRYSTAL
        if true
          :foo
        elsif false
          %w[foo bar].each do
            if 1
              :abc
            elsif 2
              :abc
            # ^^^^ error: Duplicate branch body detected
            else
              :abc
            # ^^^^ error: Duplicate branch body detected
            end
          end
          :foo
        end
        CRYSTAL
    end

    it "reports duplicated `if` / `else` branch bodies nested within `else`" do
      expect_issue subject, <<-CRYSTAL
        if true
          :foo
        else
          %w[foo bar].each do
            if 1
              :abc
            elsif 2
              :abc
            # ^^^^ error: Duplicate branch body detected
            else
              :abc
            # ^^^^ error: Duplicate branch body detected
            end
          end
        end
        CRYSTAL
    end

    it "reports duplicated `else` branch bodies within a ternary `if`" do
      expect_issue subject, <<-CRYSTAL
        true ? :foo : :foo
                    # ^^^^ error: Duplicate branch body detected
        CRYSTAL
    end

    it "reports duplicated `case` branch bodies" do
      expect_issue subject, <<-CRYSTAL
        case
        when true
          :foo
        when false
          :foo
        # ^^^^ error: Duplicate branch body detected
        end
        CRYSTAL
    end

    it "reports duplicated exception handler branch bodies" do
      expect_issue subject, <<-CRYSTAL
        begin
          :foo
        rescue ArgumentError
          :foo
        rescue OverflowError
          :foo
        # ^^^^ error: Duplicate branch body detected
        else
          :foo
        # ^^^^ error: Duplicate branch body detected
        end
        CRYSTAL
    end

    context "properties" do
      context "#ignore_literal_branches" do
        it "when disabled reports duplicated (static) literal branch bodies" do
          rule = DuplicateBranch.new
          rule.ignore_literal_branches = false

          expect_issue rule, <<-CRYSTAL
            true ? :foo : :foo
                        # ^^^^ error: Duplicate branch body detected
            true ? "foo" : "foo"
                         # ^^^^^ error: Duplicate branch body detected
            true ? 123 : 123
                       # ^^^ error: Duplicate branch body detected
            true ? [1, 2, 3] : [1, 2, 3]
                             # ^^^^^^^^^ error: Duplicate branch body detected
            true ? [foo, bar, baz] : [foo, bar, baz]
                                   # ^^^^^^^^^^^^^^^ error: Duplicate branch body detected
            CRYSTAL
        end

        it "when enabled does not report duplicated (static) literal branch bodies" do
          rule = DuplicateBranch.new
          rule.ignore_literal_branches = true

          # static literals
          expect_no_issues rule, <<-CRYSTAL
            true ? :foo : :foo
            true ? "foo" : "foo"
            true ? 123 : 123
            true ? [1, 2, 3] : [1, 2, 3]
            true ? {foo: "bar"} : {foo: "bar"}
            CRYSTAL

          # dynamic literals
          expect_issue rule, <<-CRYSTAL
            true ? [foo, bar, baz] : [foo, bar, baz]
                                   # ^^^^^^^^^^^^^^^ error: Duplicate branch body detected
            CRYSTAL
        end
      end

      context "#ignore_constant_branches" do
        it "when disabled reports constant branch bodies" do
          rule = DuplicateBranch.new
          rule.ignore_constant_branches = false

          expect_issue rule, <<-CRYSTAL
            true ? FOO : FOO
                       # ^^^ error: Duplicate branch body detected
            true ? Foo::Bar : Foo::Bar
                            # ^^^^^^^^ error: Duplicate branch body detected
            CRYSTAL
        end

        it "when enabled does not report constant branch bodies" do
          rule = DuplicateBranch.new
          rule.ignore_constant_branches = true

          expect_no_issues rule, <<-CRYSTAL
            true ? FOO : FOO
            true ? Foo::Bar : Foo::Bar
            CRYSTAL
        end
      end

      context "#ignore_duplicate_else_branch" do
        rule = DuplicateBranch.new
        rule.ignore_duplicate_else_branch = true

        context "when enabled does not report duplicated `else` branch bodies" do
          it "in `if`" do
            expect_no_issues rule, <<-CRYSTAL
              if true
                :foo
              else
                :foo
              end
              CRYSTAL
          end

          it "in ternary `if`" do
            expect_no_issues rule, <<-CRYSTAL
              true ? :foo : :foo
              CRYSTAL
          end

          it "in `unless`" do
            expect_no_issues rule, <<-CRYSTAL
              unless true
                :foo
              else
                :foo
              end
              CRYSTAL
          end

          it "in `case`" do
            expect_no_issues rule, <<-CRYSTAL
              case
              when true
                :foo
              else
                :foo
              end
              CRYSTAL
          end

          it "in exception handler" do
            expect_no_issues rule, <<-CRYSTAL
              begin
                :foo
              rescue ArgumentError
                :foo
              else
                :foo
              end
              CRYSTAL
          end
        end
      end
    end
  end
end
