require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = UnusedArgument.new
  subject.ignore_defs = false

  describe UnusedArgument do
    it "doesn't report if arguments are used" do
      expect_no_issues subject, <<-CRYSTAL
        def method(a, b, c)
          a + b + c
        end

        3.times do |i|
          i + 1
        end

        ->(i : Int32) { i + 1 }
        CRYSTAL
    end

    it "reports if method argument is unused" do
      source = expect_issue subject, <<-CRYSTAL
        def method(a, b, c)
                       # ^ error: Unused argument `c`. If it's necessary, use `_c` as an argument name to indicate that it won't be used.
          a + b
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def method(a, b, _c)
          a + b
        end
        CRYSTAL
    end

    it "reports if block argument is unused" do
      source = expect_issue subject, <<-CRYSTAL
        [1, 2].each_with_index do |a, i|
                                    # ^ error: Unused argument `i`. [...]
          a
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        [1, 2].each_with_index do |a, _|
          a
        end
        CRYSTAL
    end

    it "reports if proc argument is unused" do
      source = expect_issue subject, <<-CRYSTAL
        -> (a : Int32, b : String) do
                     # ^^^^^^^^^^ error: Unused argument `b`. If it's necessary, use `_b` as an argument name to indicate that it won't be used.
          a = a + 1
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        -> (a : Int32, _b : String) do
          a = a + 1
        end
        CRYSTAL
    end

    it "reports multiple unused args" do
      source = expect_issue subject, <<-CRYSTAL
        def method(a, b, c)
                 # ^ error: Unused argument `a`. If it's necessary, use `_a` as an argument name to indicate that it won't be used.
                    # ^ error: Unused argument `b`. If it's necessary, use `_b` as an argument name to indicate that it won't be used.
                       # ^ error: Unused argument `c`. If it's necessary, use `_c` as an argument name to indicate that it won't be used.
          nil
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def method(_a, _b, _c)
          nil
        end
        CRYSTAL
    end

    it "doesn't report if it is an instance var argument" do
      expect_no_issues subject, <<-CRYSTAL
        class A
          def method(@name)
          end
        end
        CRYSTAL
    end

    it "doesn't report if a typed argument is used" do
      expect_no_issues subject, <<-CRYSTAL
        def method(x : Int32)
          3.times do
            puts x
          end
        end
        CRYSTAL
    end

    it "doesn't report if an argument with default value is used" do
      expect_no_issues subject, <<-CRYSTAL
        def method(x = 1)
          puts x
        end
        CRYSTAL
    end

    it "doesn't report if argument starts with a _" do
      expect_no_issues subject, <<-CRYSTAL
        def method(_x)
        end
        CRYSTAL
    end

    it "doesn't report if it is a block and used" do
      expect_no_issues subject, <<-CRYSTAL
        def method(&block)
          block.call
        end
        CRYSTAL
    end

    it "doesn't report if block arg is not used" do
      expect_no_issues subject, <<-CRYSTAL
        def method(&block)
        end
        CRYSTAL
    end

    it "doesn't report if unused and there is yield" do
      expect_no_issues subject, <<-CRYSTAL
        def method(&block)
          yield 1
        end
        CRYSTAL
    end

    it "doesn't report if it's an anonymous block" do
      expect_no_issues subject, <<-CRYSTAL
        def method(&)
          yield 1
        end
        CRYSTAL
    end

    it "doesn't report if variable is referenced implicitly" do
      expect_no_issues subject, <<-CRYSTAL
        class Bar < Foo
          def method(a, b)
            super
          end
        end
        CRYSTAL
    end

    it "doesn't report if arg if referenced in case" do
      expect_no_issues subject, <<-CRYSTAL
        def foo(a)
          case a
          when /foo/
          end
        end
        CRYSTAL
    end

    it "doesn't report if enum in a record" do
      expect_no_issues subject, <<-CRYSTAL
        class Class
          record Record do
            enum Enum
              CONSTANT
            end
          end
        end
        CRYSTAL
    end

    context "super" do
      it "reports if variable is not referenced implicitly by super" do
        source = expect_issue subject, <<-CRYSTAL
          class Bar < Foo
            def method(a, b)
                        # ^ error: Unused argument `b`. If it's necessary, use `_b` as an argument name to indicate that it won't be used.
              super a
            end
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          class Bar < Foo
            def method(a, _b)
              super a
            end
          end
          CRYSTAL
      end
    end

    context "macro" do
      it "doesn't report if it is a used macro argument" do
        expect_no_issues subject, <<-CRYSTAL
          macro my_macro(arg)
            {% arg %}
          end
          CRYSTAL
      end

      it "doesn't report if it is a used macro block argument" do
        expect_no_issues subject, <<-CRYSTAL
          macro my_macro(&block)
            {% block %}
          end
          CRYSTAL
      end

      it "doesn't report used macro args with equal names in record" do
        expect_no_issues subject, <<-CRYSTAL
          record X do
            macro foo(a, b)
              {{ a }} + {{ b }}
            end

            macro bar(a, b, c)
              {{ a }} + {{ b }} + {{ c }}
            end
          end
          CRYSTAL
      end

      it "doesn't report used args in macro literals" do
        expect_no_issues subject, <<-CRYSTAL
          def print(f : Array(U)) forall U
            f.size.times do |i|
              {% if U == Float64 %}
                puts f[i].round(3)
              {% else %}
                puts f[i]
              {% end %}
            end
          end
          CRYSTAL
      end
    end

    context "properties" do
      describe "#ignore_defs" do
        it "lets the rule to ignore def scopes if true" do
          rule = UnusedArgument.new
          rule.ignore_defs = true

          expect_no_issues rule, <<-CRYSTAL
            def method(a)
            end
            CRYSTAL
        end

        it "lets the rule not to ignore def scopes if false" do
          rule = UnusedArgument.new
          rule.ignore_defs = false

          expect_issue rule, <<-CRYSTAL
            def method(a)
                     # ^ error: Unused argument `a`. If it's necessary, use `_a` as an argument name to indicate that it won't be used.
            end
            CRYSTAL
        end
      end

      context "#ignore_blocks" do
        it "lets the rule to ignore block scopes if true" do
          rule = UnusedArgument.new
          rule.ignore_blocks = true

          expect_no_issues rule, <<-CRYSTAL
            3.times { |i| puts "yo!" }
            CRYSTAL
        end

        it "lets the rule not to ignore block scopes if false" do
          rule = UnusedArgument.new
          rule.ignore_blocks = false

          expect_issue rule, <<-CRYSTAL
            3.times { |i| puts "yo!" }
                     # ^ error: Unused argument `i`. If it's necessary, use `_` as an argument name to indicate that it won't be used.
            CRYSTAL
        end
      end

      context "#ignore_procs" do
        it "lets the rule to ignore proc scopes if true" do
          rule = UnusedArgument.new
          rule.ignore_procs = true

          expect_no_issues rule, <<-CRYSTAL
            ->(a : Int32) {}
            CRYSTAL
        end

        it "lets the rule not to ignore proc scopes if false" do
          rule = UnusedArgument.new
          rule.ignore_procs = false

          expect_issue rule, <<-CRYSTAL
            ->(a : Int32) {}
             # ^^^^^^^^^ error: Unused argument `a`. If it's necessary, use `_a` as an argument name to indicate that it won't be used.
            CRYSTAL
        end
      end
    end
  end
end
