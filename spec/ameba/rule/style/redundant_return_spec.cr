require "../../../spec_helper"

module Ameba::Rule::Style
  describe RedundantReturn do
    subject = RedundantReturn.new

    it "does not report if there is no return" do
      expect_no_issues subject, <<-CRYSTAL
        def inc(a)
          a + 1
        end
        CRYSTAL
    end

    it "reports if there is redundant return in method body" do
      source = expect_issue subject, <<-CRYSTAL
        def inc(a)
          return a + 1
        # ^^^^^^ error: Redundant `return` detected
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def inc(a)
          a + 1
        end
        CRYSTAL
    end

    context "right side of a binary operator" do
      it "keeps the meaning of a ternary" do
        source = expect_issue subject, <<-CRYSTAL
          def foo(a, b)
            a || return b ? 1 : 2
               # ^^^^^^ error: Redundant `return` detected
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          def foo(a, b)
            a || (b ? 1 : 2)
          end
          CRYSTAL
      end

      it "keeps the meaning of a lower precedence operator" do
        source = expect_issue subject, <<-CRYSTAL
          def foo(a, b, c)
            a && return b || c
               # ^^^^^^ error: Redundant `return` detected
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          def foo(a, b, c)
            a && (b || c)
          end
          CRYSTAL
      end

      it "keeps the code parsable with an assignment" do
        source = expect_issue subject, <<-CRYSTAL
          def foo(a)
            a || return b = 1
               # ^^^^^^ error: Redundant `return` detected
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          def foo(a)
            a || (b = 1)
          end
          CRYSTAL
      end

      it "doesn't correct if a heredoc would have to be wrapped in parentheses" do
        source = expect_issue subject, <<-CRYSTAL
          def foo(a)
            a || return foo <<-TEXT
               # ^^^^^^ error: Redundant `return` detected
              a
              TEXT
          end
          CRYSTAL

        expect_no_corrections source
      end

      it "doesn't add parentheses around a value binding tightly" do
        source = expect_issue subject, <<-CRYSTAL
          def foo(a, b)
            a || return b
               # ^^^^^^ error: Redundant `return` detected
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          def foo(a, b)
            a || b
          end
          CRYSTAL
      end

      it "doesn't add parentheses to a return following an operand" do
        source = expect_issue subject, <<-CRYSTAL
          def foo(a, b)
            if a
              a || return b
                 # ^^^^^^ error: Redundant `return` detected
            else
              return b ? 1 : 2
            # ^^^^^^ error: Redundant `return` detected
            end
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          def foo(a, b)
            if a
              a || b
            else
              b ? 1 : 2
            end
          end
          CRYSTAL
      end

      it "doesn't add parentheses to the same expression elsewhere" do
        source = expect_issue subject, <<-CRYSTAL
          def foo(a, b)
            return b ? 1 : 2 if a
          # ^^^^^^ error: Redundant `return` detected
          end

          def bar(a, b, c)
            a || begin
              if b
                return b ? 1 : 2
              # ^^^^^^ error: Redundant `return` detected
              end
            end
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          def foo(a, b)
            b ? 1 : 2 if a
          end

          def bar(a, b, c)
            a || begin
              if b
                b ? 1 : 2
              end
            end
          end
          CRYSTAL
      end
    end

    context "arguments in parentheses" do
      it "corrects to the argument" do
        source = expect_issue subject, <<-CRYSTAL
          def foo(a)
            return(a)
          # ^^^^^^ error: Redundant `return` detected
          end

          def bar(a)
            return( nil ) if a
          # ^^^^^^ error: Redundant `return` detected
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          def foo(a)
            a
          end

          def bar(a)
            nil if a
          end
          CRYSTAL
      end

      it "corrects multiline arguments" do
        source = expect_issue subject, <<-CRYSTAL
          def foo
            return(
          # ^^^^^^ error: Redundant `return` detected
              1
            )
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          def foo
            1
          end
          CRYSTAL
      end

      it "keeps the parentheses if the argument could bind differently without them" do
        source = expect_issue subject, <<-CRYSTAL
          def foo(a, b)
            a || return(b ? 1 : 2)
               # ^^^^^^ error: Redundant `return` detected
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          def foo(a, b)
            a || (b ? 1 : 2)
          end
          CRYSTAL
      end

      it "corrects tuple literal" do
        rule = RedundantReturn.new
        rule.allow_multi_return = false

        source = expect_issue rule, <<-CRYSTAL
          def foo
            return(1, 2)
          # ^^^^^^ error: Redundant `return` detected
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          def foo
            {1, 2}
          end
          CRYSTAL
      end

      it "doesn't correct if the closing parenthesis can't be found" do
        source = expect_issue subject, <<-CRYSTAL
          def foo
            return(<<-TEXT)
          # ^^^^^^ error: Redundant `return` detected
              a
              TEXT
          end
          CRYSTAL

        expect_no_corrections source
      end

      it "doesn't correct if the argument contains a heredoc" do
        source = expect_issue subject, <<-CRYSTAL
          def foo(a)
            return(<<-TEXT
          # ^^^^^^ error: Redundant `return` detected
              a
              TEXT
            ) if a
          end
          CRYSTAL

        expect_no_corrections source
      end

      it "doesn't correct if that would glue the argument to what follows" do
        source = expect_issue subject, <<-CRYSTAL
          def foo(a, b)
            return(a)if b
          # ^^^^^^ error: Redundant `return` detected
          end

          def bar(a, b)
            return(a + 1)unless b
          # ^^^^^^ error: Redundant `return` detected
          end
          CRYSTAL

        expect_no_corrections source
      end

      it "doesn't correct if that would lose a comment" do
        source = expect_issue subject, <<-CRYSTAL
          def foo
            return(
          # ^^^^^^ error: Redundant `return` detected
              1 # one
            )
          end

          def bar
            return( # one
          # ^^^^^^ error: Redundant `return` detected
              1
            )
          end
          CRYSTAL

        expect_no_corrections source
      end
    end

    it "corrects return followed by an expression in parentheses" do
      source = expect_issue subject, <<-CRYSTAL
        def foo
          return (1)
        # ^^^^^^ error: Redundant `return` detected
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def foo
          (1)
        end
        CRYSTAL
    end

    it "doesn't report if it returns tuple literal" do
      expect_no_issues subject, <<-CRYSTAL
        def foo(a)
          return a, a + 2
        end
        CRYSTAL
    end

    it "doesn't report if there are other expressions after control flow" do
      expect_no_issues subject, <<-CRYSTAL
        def method(a)
          case a
          when true  then return true
          when .nil? then return :nil
          end
          false
        rescue
          nil
        end
        CRYSTAL
    end

    context "if" do
      it "reports if there is return in if branch" do
        source = expect_issue subject, <<-CRYSTAL
          def inc(a)
            return a + 1 if a > 0
          # ^^^^^^ error: Redundant `return` detected
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          def inc(a)
            a + 1 if a > 0
          end
          CRYSTAL
      end

      it "reports if there are returns in if/else branch" do
        source = expect_issue subject, <<-CRYSTAL
          def inc(a)
            do_something(a)
            if a > 0
              return :positive
            # ^^^^^^ error: Redundant `return` detected
            else
              return :negative
            # ^^^^^^ error: Redundant `return` detected
            end
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          def inc(a)
            do_something(a)
            if a > 0
              :positive
            else
              :negative
            end
          end
          CRYSTAL
      end
    end

    context "unless" do
      it "reports if there is return in unless branch" do
        source = expect_issue subject, <<-CRYSTAL
          def inc(a)
            return a + 1 unless a > 0
          # ^^^^^^ error: Redundant `return` detected
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          def inc(a)
            a + 1 unless a > 0
          end
          CRYSTAL
      end

      it "reports if there are returns in unless/else branch" do
        source = expect_issue subject, <<-CRYSTAL
          def inc(a)
            do_something(a)
            unless a < 0
              return :positive
            # ^^^^^^ error: Redundant `return` detected
            else
              return :negative
            # ^^^^^^ error: Redundant `return` detected
            end
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          def inc(a)
            do_something(a)
            unless a < 0
              :positive
            else
              :negative
            end
          end
          CRYSTAL
      end
    end

    context "binary op" do
      it "doesn't report if there is no return in the right binary op node" do
        expect_no_issues subject, <<-CRYSTAL
          def can_create?(a)
            valid? && a > 0
          end
          CRYSTAL
      end

      it "reports if there is return in the right binary op node" do
        source = expect_issue subject, <<-CRYSTAL
          def can_create?(a)
            valid? && return a > 0
                    # ^^^^^^ error: Redundant `return` detected
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          def can_create?(a)
            valid? && a > 0
          end
          CRYSTAL
      end
    end

    context "case" do
      it "reports if there are returns in whens" do
        source = expect_issue subject, <<-CRYSTAL
          def foo(a)
            case a
            when .nil?
              puts "blah"
              return nil
            # ^^^^^^ error: Redundant `return` detected
            when .blank?
              return ""
            # ^^^^^^ error: Redundant `return` detected
            when true
              true
            end
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          def foo(a)
            case a
            when .nil?
              puts "blah"
              nil
            when .blank?
              ""
            when true
              true
            end
          end
          CRYSTAL
      end

      it "reports if there is return in else" do
        source = expect_issue subject, <<-CRYSTAL
          def foo(a)
            do_something_with(a)

            case a
            when true
              true
            else
              return false
            # ^^^^^^ error: Redundant `return` detected
            end
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          def foo(a)
            do_something_with(a)

            case a
            when true
              true
            else
              false
            end
          end
          CRYSTAL
      end
    end

    context "exception handler" do
      it "doesn't report return in body if there is an else branch" do
        expect_no_issues subject, <<-CRYSTAL
          def foo
            begin
              return 1
            rescue
              2
            else
              3
              4
            end
          ensure
            5
          end

          def bar
            return 1
          rescue
            2
          else
            3
          end
          CRYSTAL
      end

      it "reports return in the rescue and else branches if there is an else branch" do
        source = expect_issue subject, <<-CRYSTAL
          def foo
            1
          rescue
            return 2
          # ^^^^^^ error: Redundant `return` detected
          else
            return 3
          # ^^^^^^ error: Redundant `return` detected
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          def foo
            1
          rescue
            2
          else
            3
          end
          CRYSTAL
      end

      it "reports return in body if there is only an ensure branch" do
        source = expect_issue subject, <<-CRYSTAL
          def foo
            return 1
          # ^^^^^^ error: Redundant `return` detected
          ensure
            2
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          def foo
            1
          ensure
            2
          end
          CRYSTAL
      end

      it "reports if there are returns in body" do
        source = expect_issue subject, <<-CRYSTAL
          def foo(a)
            return true
          # ^^^^^^ error: Redundant `return` detected
          rescue
            false
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          def foo(a)
            true
          rescue
            false
          end
          CRYSTAL
      end

      it "reports if there are returns in rescues" do
        source = expect_issue subject, <<-CRYSTAL
          def foo(a)
            true
          rescue ArgumentError
            return false
          # ^^^^^^ error: Redundant `return` detected
          rescue RuntimeError
            ""
          rescue Exception
            return nil
          # ^^^^^^ error: Redundant `return` detected
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          def foo(a)
            true
          rescue ArgumentError
            false
          rescue RuntimeError
            ""
          rescue Exception
            nil
          end
          CRYSTAL
      end

      it "reports if there are returns in else" do
        source = expect_issue subject, <<-CRYSTAL
          def foo(a)
            true
          rescue Exception
            nil
          else
            puts "else branch"
            return :bar
          # ^^^^^^ error: Redundant `return` detected
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          def foo(a)
            true
          rescue Exception
            nil
          else
            puts "else branch"
            :bar
          end
          CRYSTAL
      end
    end

    context "properties" do
      context "#allow_multi_return" do
        it "allows multi returns by default" do
          expect_no_issues subject, <<-CRYSTAL
            def method(a, b)
              return a, b
            end
            CRYSTAL
        end

        it "allows to configure multi returns" do
          rule = subject.class.new
          rule.allow_multi_return = false

          source = expect_issue rule, <<-CRYSTAL
            def method(a, b)
              return a, b
            # ^^^^^^ error: Redundant `return` detected
            end
            CRYSTAL

          expect_correction source, <<-CRYSTAL
            def method(a, b)
              {a, b}
            end
            CRYSTAL
        end
      end

      context "#allow_empty_return" do
        it "allows empty returns by default" do
          expect_no_issues subject, <<-CRYSTAL
            def method
              return
            end
            CRYSTAL
        end

        it "allows to configure empty returns" do
          rule = subject.class.new
          rule.allow_empty_return = false

          source = expect_issue rule, <<-CRYSTAL
            def method
              return
            # ^^^^^^ error: Redundant `return` detected
            end
            CRYSTAL

          expect_no_corrections source
        end
      end
    end
  end
end
