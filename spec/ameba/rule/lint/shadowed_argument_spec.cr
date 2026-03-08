require "../../../spec_helper"

module Ameba::Rule::Lint
  describe ShadowedArgument do
    subject = ShadowedArgument.new

    it "doesn't report if there is not a shadowed argument" do
      expect_no_issues subject, <<-CRYSTAL
        def foo(bar)
          baz = 1
        end

        3.times do |i|
          a = 1
        end

        proc = -> (a : Int32) {
          b = 2
        }
        CRYSTAL
    end

    it "reports if there is a shadowed method argument" do
      expect_issue subject, <<-CRYSTAL
        def foo(bar)
          bar = 1
        # ^^^^^^^ error: Argument `bar` is assigned before it is used
          bar
        end
        CRYSTAL
    end

    it "reports if there is a shadowed block argument" do
      expect_issue subject, <<-CRYSTAL
        3.times do |i|
          i = 2
        # ^^^^^ error: Argument `i` is assigned before it is used
        end
        CRYSTAL
    end

    it "reports if there is a shadowed proc argument" do
      expect_issue subject, <<-CRYSTAL
        -> (x : Int32) {
          x = 20
        # ^^^^^^ error: Argument `x` is assigned before it is used
          x
        }
        CRYSTAL
    end

    it "doesn't report if the argument is referenced before the assignment" do
      expect_no_issues subject, <<-CRYSTAL
        def foo(bar)
          bar
          bar = 1
        end
        CRYSTAL
    end

    it "doesn't report if the argument is conditionally reassigned" do
      expect_no_issues subject, <<-CRYSTAL
        def foo(bar = nil)
          bar ||= true
          bar
        end
        CRYSTAL
    end

    it "doesn't report if the op assign is followed by another assignment" do
      expect_no_issues subject, <<-CRYSTAL
        def foo(bar)
          bar ||= 3
          bar = 43
          bar
        end
        CRYSTAL
    end

    it "reports if the shadowing assignment is followed by op assign" do
      expect_issue subject, <<-CRYSTAL
        def foo(bar)
          bar = 42
        # ^^^^^^^^ error: Argument `bar` is assigned before it is used
          bar ||= 43
          bar
        end
        CRYSTAL
    end

    it "doesn't report if the argument is unused" do
      expect_no_issues subject, <<-CRYSTAL
        def foo(bar)
        end
        CRYSTAL
    end

    it "doesn't report if the argument is reassigned from super result" do
      expect_no_issues subject, <<-CRYSTAL
        def foo(bar)
          bar = super
          bar
        end
        CRYSTAL
    end

    it "doesn't report if the argument is reassigned from previous_def result" do
      expect_no_issues subject, <<-CRYSTAL
        def foo(bar)
          bar = previous_def
          bar
        end
        CRYSTAL
    end

    it "reports if the argument is shadowed before super" do
      expect_issue subject, <<-CRYSTAL
        def foo(bar)
          bar = 1
        # ^^^^^^^ error: Argument `bar` is assigned before it is used
          super
        end
        CRYSTAL
    end

    context "branch" do
      it "doesn't report if the argument is not shadowed in a condition" do
        expect_no_issues subject, <<-CRYSTAL
          def foo(bar, baz)
            bar = 1 if baz
            bar
          end
          CRYSTAL
      end

      it "reports if the argument is shadowed after the condition" do
        expect_issue subject, <<-CRYSTAL
          def foo(foo)
            if something
              foo = 42
            end
            foo = 43
          # ^^^^^^^^ error: Argument `foo` is assigned before it is used
            foo
          end
          CRYSTAL
      end

      it "doesn't report if the argument is conditionally assigned in a branch" do
        expect_no_issues subject, <<-CRYSTAL
          def foo(bar)
            if something
              bar ||= 22
            end
            bar
          end
          CRYSTAL
      end
    end

    context "inner scopes" do
      it "doesn't report if the argument is used in an inner block" do
        expect_no_issues subject, <<-CRYSTAL
          def foo(catch_all = false)
            items.each do |item|
              if catch_all
                do_something
              end
              catch_all = true
            end
          end
          CRYSTAL
      end

      it "doesn't report if the argument is captured by a block" do
        expect_no_issues subject, <<-CRYSTAL
          def foo(token)
            loop do
              token = next_token(token.state)
              process(token)
              break if token.eof?
            end
          end
          CRYSTAL
      end

      it "doesn't report if the argument is referenced in an inner scope" do
        expect_no_issues subject, <<-CRYSTAL
          def foo(x)
            x = 1
            3.times { puts x }
          end
          CRYSTAL
      end

      it "doesn't report if the argument is used in a macro" do
        expect_no_issues subject, <<-CRYSTAL
          def foo(bar)
            bar = 1
            {% if flag?(:release) %}
              use(bar)
            {% end %}
          end
          CRYSTAL
      end
    end
  end
end
