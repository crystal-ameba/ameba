require "../../../spec_helper"

module Ameba::Rule::Style
  subject = RedundantReturn.new

  describe RedundantReturn do
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
        # ^^^^^^^^^^^^ error: Redundant `return` detected
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def inc(a)
          a + 1
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
          when true then return true
          when .nil? then return :nil
          end
          false
        rescue
          nil
        end
        CRYSTAL
    end

    context "if" do
      it "doesn't report if there is return in if branch" do
        expect_no_issues subject, <<-CRYSTAL
          def inc(a)
            return a + 1 if a > 0
          end
          CRYSTAL
      end

      it "reports if there are returns in if/else branch" do
        source = expect_issue subject, <<-CRYSTAL
          def inc(a)
            do_something(a)
            if a > 0
              return :positive
            # ^^^^^^^^^^^^^^^^ error: Redundant `return` detected
            else
              return :negative
            # ^^^^^^^^^^^^^^^^ error: Redundant `return` detected
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
      it "doesn't report if there is return in unless branch" do
        expect_no_issues subject, <<-CRYSTAL
          def inc(a)
            return a + 1 unless a > 0
          end
          CRYSTAL
      end

      it "reports if there are returns in unless/else branch" do
        source = expect_issue subject, <<-CRYSTAL
          def inc(a)
            do_something(a)
            unless a < 0
              return :positive
            # ^^^^^^^^^^^^^^^^ error: Redundant `return` detected
            else
              return :negative
            # ^^^^^^^^^^^^^^^^ error: Redundant `return` detected
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
                    # ^^^^^^^^^^^^ error: Redundant `return` detected
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
            # ^^^^^^^^^^ error: Redundant `return` detected
            when .blank?
              return ""
            # ^^^^^^^^^ error: Redundant `return` detected
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
            # ^^^^^^^^^^^^ error: Redundant `return` detected
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
      it "reports if there are returns in body" do
        source = expect_issue subject, <<-CRYSTAL
          def foo(a)
            return true
          # ^^^^^^^^^^^ error: Redundant `return` detected
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
          # ^^^^^^^^^^^^ error: Redundant `return` detected
          rescue RuntimeError
            ""
          rescue Exception
            return nil
          # ^^^^^^^^^^ error: Redundant `return` detected
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
          # ^^^^^^^^^^^ error: Redundant `return` detected
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
          rule = RedundantReturn.new
          rule.allow_multi_return = false
          source = expect_issue rule, <<-CRYSTAL
            def method(a, b)
              return a, b
            # ^^^^^^^^^^^ error: Redundant `return` detected
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
          rule = RedundantReturn.new
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
