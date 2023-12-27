require "../../../spec_helper"

module Ameba::Rule::Lint
  describe UselessAssign do
    subject = UselessAssign.new

    it "does not report used assignments" do
      expect_no_issues subject, <<-CRYSTAL
        def method
          a = 2
          a
        end
        CRYSTAL
    end

    it "reports a useless assignment in a method" do
      expect_issue subject, <<-CRYSTAL
        def method
          a = 2
        # ^ error: Useless assignment to variable `a`
        end
        CRYSTAL
    end

    it "reports a useless assignment in a proc" do
      expect_issue subject, <<-CRYSTAL
        ->() {
          a = 2
        # ^ error: Useless assignment to variable `a`
        }
        CRYSTAL
    end

    it "reports a useless assignment in a block" do
      expect_issue subject, <<-CRYSTAL
        def method
          3.times do
            a = 1
          # ^ error: Useless assignment to variable `a`
          end
        end
        CRYSTAL
    end

    it "reports a useless assignment in a proc inside def" do
      expect_issue subject, <<-CRYSTAL
        def method
          ->() {
            a = 2
          # ^ error: Useless assignment to variable `a`
          }
        end
        CRYSTAL
    end

    it "does not report ignored assignments" do
      expect_no_issues subject, <<-CRYSTAL
        payload, _header = decode
        puts payload
        CRYSTAL
    end

    it "reports a useless assignment in a proc inside a block" do
      expect_issue subject, <<-CRYSTAL
        def method
          3.times do
            ->() {
              a = 2
            # ^ error: Useless assignment to variable `a`
            }
          end
        end
        CRYSTAL
    end

    it "does not report useless assignment of instance var" do
      expect_no_issues subject, <<-CRYSTAL
        class Cls
          def initialize(@name)
          end
        end
        CRYSTAL
    end

    it "does not report if assignment used in the inner block scope" do
      expect_no_issues subject, <<-CRYSTAL
        def method
          var = true
          3.times { var = false }
        end
        CRYSTAL
    end

    it "reports if assigned is not referenced in the inner block scope" do
      expect_issue subject, <<-CRYSTAL
        def method
          var = true
        # ^^^ error: Useless assignment to variable `var`
          3.times {}
        end
        CRYSTAL
    end

    it "doesn't report if assignment in referenced in inner block" do
      expect_no_issues subject, <<-CRYSTAL
        def method
          two = true

          3.times do
            mutex.synchronize do
              two = 2
            end
          end

          two.should be_true
        end
        CRYSTAL
    end

    it "reports if first assignment is useless" do
      expect_issue subject, <<-CRYSTAL
        def method
          var = true
        # ^^^ error: Useless assignment to variable `var`
          var = false
          var
        end
        CRYSTAL
    end

    it "reports if variable reassigned and not used" do
      expect_issue subject, <<-CRYSTAL
        def method
          var = true
        # ^^^ error: Useless assignment to variable `var`
          var = false
        # ^^^ error: Useless assignment to variable `var`
        end
        CRYSTAL
    end

    it "does not report if variable used in a condition" do
      expect_no_issues subject, <<-CRYSTAL
        def method
          a = 1
          if a
            nil
          end
        end
        CRYSTAL
    end

    it "reports second assignment as useless" do
      expect_issue subject, <<-CRYSTAL
        def method
          a = 1
          a = a + 1
        # ^ error: Useless assignment to variable `a`
        end
        CRYSTAL
    end

    it "does not report if variable is referenced in other assignment" do
      expect_no_issues subject, <<-CRYSTAL
        def method
          if f = get_something
            @f = f
          end
        end
        CRYSTAL
    end

    it "does not report if variable is referenced in a setter" do
      expect_no_issues subject, <<-CRYSTAL
        def method
          foo = 2
          table[foo] ||= "bar"
        end
        CRYSTAL
    end

    it "does not report if variable is reassigned but not referenced" do
      expect_issue subject, <<-CRYSTAL
        def method
          foo = 1
          puts foo
          foo = 2
        # ^^^ error: Useless assignment to variable `foo`
        end
        CRYSTAL
    end

    it "does not report if variable is referenced in a call" do
      expect_no_issues subject, <<-CRYSTAL
        def method
          if f = FORMATTER
            @formatter = f.new
          end
        end
        CRYSTAL
    end

    it "does not report if a setter is invoked with operator assignment" do
      expect_no_issues subject, <<-CRYSTAL
        def method
          obj = {} of Symbol => Int32
          obj[:name] = 3
        end
        CRYSTAL
    end

    context "block unpacking" do
      it "does not report if the first arg is transformed and not used" do
        expect_no_issues subject, <<-CRYSTAL
          collection.each do |(a, b)|
            puts b
          end
          CRYSTAL
      end

      it "does not report if the second arg is transformed and not used" do
        expect_no_issues subject, <<-CRYSTAL
          collection.each do |(a, b)|
            puts a
          end
          CRYSTAL
      end

      it "does not report if all transformed args are not used in a block" do
        expect_no_issues subject, <<-CRYSTAL
          collection.each do |(foo, bar), (baz, _qux), index, object|
          end
          CRYSTAL
      end
    end

    it "does not report if assignment is referenced in a proc" do
      expect_no_issues subject, <<-CRYSTAL
        def method
          called = false
          ->() { called = true }
          called
        end
        CRYSTAL
    end

    it "reports if variable is shadowed in inner scope" do
      expect_issue subject, <<-CRYSTAL
        def method
          i = 1
        # ^ error: Useless assignment to variable `i`
          3.times do |i|
            i + 1
          end
        end
        CRYSTAL
    end

    it "does not report if parameter is referenced after the branch" do
      expect_no_issues subject, <<-CRYSTAL
        def method(param)
          3.times do
            param = 3
          end
          param
        end
        CRYSTAL
    end

    context "op assigns" do
      it "does not report if variable is referenced below the op assign" do
        expect_no_issues subject, <<-CRYSTAL
          def method
            a = 1
            a += 1
            a
          end
          CRYSTAL
      end

      it "does not report if variable is referenced in op assign few times" do
        expect_no_issues subject, <<-CRYSTAL
          def method
            a = 1
            a += 1
            a += 1
            a = a + 1
            a
          end
          CRYSTAL
      end

      it "reports if variable is not referenced below the op assign" do
        expect_issue subject, <<-CRYSTAL
          def method
            a = 1
            a += 1
          # ^ error: Useless assignment to variable `a`
          end
          CRYSTAL
      end
    end

    context "multi assigns" do
      it "does not report if all assigns are referenced" do
        expect_no_issues subject, <<-CRYSTAL
          def method
            a, b = {1, 2}
            a + b
          end
          CRYSTAL
      end

      it "reports if one assign is not referenced" do
        expect_issue subject, <<-CRYSTAL
          def method
            a, b = {1, 2}
             # ^ error: Useless assignment to variable `b`
            a
          end
          CRYSTAL
      end

      it "reports if both assigns are reassigned and useless" do
        expect_issue subject, <<-CRYSTAL
          def method
            a, b = {1, 2}
          # ^ error: Useless assignment to variable `a`
             # ^ error: Useless assignment to variable `b`
            a, b = {3, 4}
          # ^ error: Useless assignment to variable `a`
             # ^ error: Useless assignment to variable `b`
          end
          CRYSTAL
      end

      it "reports if both assigns are not referenced" do
        expect_issue subject, <<-CRYSTAL
          def method
            a, b = {1, 2}
          # ^ error: Useless assignment to variable `a`
             # ^ error: Useless assignment to variable `b`
          end
          CRYSTAL
      end
    end

    context "top level" do
      it "reports if assignment is not referenced" do
        expect_issue subject, <<-CRYSTAL
          a = 1
          # ^{} error: Useless assignment to variable `a`
          a = 2
          # ^{} error: Useless assignment to variable `a`
          CRYSTAL
      end

      it "doesn't report if assignments are referenced" do
        expect_no_issues subject, <<-CRYSTAL
          a = 1
          a += 1
          a

          b, c = {1, 2}
          b
          c
          CRYSTAL
      end

      it "doesn't report if assignment is captured by block" do
        expect_no_issues subject, <<-CRYSTAL
          a = 1

          3.times do
            a = 2
          end
          CRYSTAL
      end

      it "doesn't report if assignment initialized and captured by block" do
        expect_no_issues subject, <<-CRYSTAL
          a : String? = nil

          1.times do
            a = "Fotis"
          end
          CRYSTAL
      end

      it "doesn't report if this is a record declaration" do
        expect_no_issues subject, <<-CRYSTAL
          record Foo, foo = "foo"
          CRYSTAL
      end

      it "does not report if assignment is referenced after the record declaration" do
        expect_no_issues subject, <<-CRYSTAL
          foo = 2
          record Bar, foo = 3 # foo = 3 is not parsed as assignment
          puts foo
          CRYSTAL
      end

      it "reports if assignment is not referenced after the record declaration" do
        expect_issue subject, <<-CRYSTAL
          foo = 2
          # ^ error: Useless assignment to variable `foo`
          record Bar, foo = 3
          CRYSTAL
      end

      it "doesn't report if type declaration assigned inside module and referenced" do
        expect_no_issues subject, <<-CRYSTAL
          module A
            foo : String? = "foo"

            bar do
              foo = "bar"
            end

            p foo
          end
          CRYSTAL
      end

      it "reports if type declaration assigned inside class" do
        expect_issue subject, <<-CRYSTAL
          class A
            foo : String? = "foo"
          # ^^^^^^^^^^^^^^^^^^^^^ error: Useless assignment to variable `foo`

            def method
              foo = "bar"
            # ^^^ error: Useless assignment to variable `foo`
            end
          end
          CRYSTAL
      end
    end

    context "branching" do
      context "if-then-else" do
        it "doesn't report if assignment is consumed by branches" do
          expect_no_issues subject, <<-CRYSTAL
            def method
              a = 0
              if something
                a = 1
              else
                a = 2
              end
              a
            end
            CRYSTAL
        end

        it "doesn't report if assignment is in one branch" do
          expect_no_issues subject, <<-CRYSTAL
            def method
              a = 0
              if something
                a = 1
              else
                nil
              end
              a
            end
            CRYSTAL
        end

        it "doesn't report if assignment is in one line branch" do
          expect_no_issues subject, <<-CRYSTAL
            def method
              a = 0
              a = 1 if something
              a
            end
            CRYSTAL
        end

        it "reports if assignment is useless in the branch" do
          expect_issue subject, <<-CRYSTAL
            def method(a)
              if a
                a = 2
              # ^ error: Useless assignment to variable `a`
              end
            end
            CRYSTAL
        end

        it "reports if only last assignment is referenced in a branch" do
          expect_issue subject, <<-CRYSTAL
            def method(a)
              a = 1
              if a
                a = 2
              # ^ error: Useless assignment to variable `a`
                a = 3
              end
              a
            end
            CRYSTAL
        end

        it "does not report of assignments are referenced in all branches" do
          expect_no_issues subject, <<-CRYSTAL
            def method
              if matches
                matches = owner.lookup_matches signature
              else
                matches = owner.lookup_matches signature
              end
              matches
            end
            CRYSTAL
        end

        it "does not report referenced assignments in inner branches" do
          expect_no_issues subject, <<-CRYSTAL
            def method
              has_newline = false

              if something
                do_something unless false
                has_newline = false
              else
                do_something if true
                has_newline = true
              end

              has_newline
            end
            CRYSTAL
        end
      end

      context "unless-then-else" do
        it "doesn't report if assignment is consumed by branches" do
          expect_no_issues subject, <<-CRYSTAL
            def method
              a = 0
              unless something
                a = 1
              else
                a = 2
              end
              a
            end
            CRYSTAL
        end

        it "reports if there is a useless assignment in a branch" do
          expect_issue subject, <<-CRYSTAL
            def method
              a = 0
              unless something
                a = 1
              # ^ error: Useless assignment to variable `a`
                a = 2
              else
                a = 2
              end
              a
            end
            CRYSTAL
        end
      end

      context "case" do
        it "does not report if assignment is referenced" do
          expect_no_issues subject, <<-CRYSTAL
            def method(a)
              case a
              when /foo/
                a = 1
              when /bar/
                a = 2
              end
              puts a
            end
            CRYSTAL
        end

        it "reports if assignment is useless" do
          expect_issue subject, <<-CRYSTAL
            def method(a)
              case a
              when /foo/
                a = 1
              # ^ error: Useless assignment to variable `a`
              when /bar/
                a = 2
              # ^ error: Useless assignment to variable `a`
              end
            end
            CRYSTAL
        end

        it "doesn't report if assignment is referenced in cond" do
          expect_no_issues subject, <<-CRYSTAL
            def method
              a = 2
              case a
              when /foo/
              end
            end
            CRYSTAL
        end
      end

      context "binary operator" do
        it "does not report if assignment is referenced" do
          expect_no_issues subject, <<-CRYSTAL
            def method(a)
              (a = 1) && (b = 1)
              a + b
            end
            CRYSTAL
        end

        it "reports if assignment is useless" do
          expect_issue subject, <<-CRYSTAL
            def method(a)
              (a = 1) || (b = 1)
                        # ^ error: Useless assignment to variable `b`
              a
            end
            CRYSTAL
        end
      end

      context "while" do
        it "does not report if assignment is referenced" do
          expect_no_issues subject, <<-CRYSTAL
            def method(a)
              while a < 10
                a = a + 1
              end
              a
            end
            CRYSTAL
        end

        it "reports if assignment is useless" do
          expect_issue subject, <<-CRYSTAL
            def method(a)
              while a < 10
                b = a
              # ^ error: Useless assignment to variable `b`
              end
            end
            CRYSTAL
        end

        it "does not report if assignment is referenced in a loop" do
          expect_no_issues subject, <<-CRYSTAL
            def method
              a = 3
              result = 0

              while result < 10
                result += a
                a = a + 1
              end
              result
            end
            CRYSTAL
        end

        it "does not report if assignment is referenced as param in a loop" do
          expect_no_issues subject, <<-CRYSTAL
            def method(a)
              result = 0

              while result < 10
                result += a
                a = a + 1
              end
              result
            end
            CRYSTAL
        end

        it "does not report if assignment is referenced in loop and inner branch" do
          expect_no_issues subject, <<-CRYSTAL
            def method(a)
              result = 0

              while result < 10
                result += a
                if result > 0
                  a = a + 1
                else
                  a = 3
                end
              end
              result
            end
            CRYSTAL
        end

        it "works properly if there is branch with blank node" do
          expect_no_issues subject, <<-CRYSTAL
            def visit
              count = 0
              while true
                break if count == 1
                case something
                when :any
                else
                  :anything_else
                end
                count += 1
              end
            end
            CRYSTAL
        end
      end

      context "until" do
        it "does not report if assignment is referenced" do
          expect_no_issues subject, <<-CRYSTAL
            def method(a)
              until a > 10
                a = a + 1
              end
              a
            end
            CRYSTAL
        end

        it "reports if assignment is useless" do
          expect_issue subject, <<-CRYSTAL
            def method(a)
              until a > 10
                b = a + 1
              # ^ error: Useless assignment to variable `b`
              end
            end
            CRYSTAL
        end
      end

      context "exception handler" do
        it "does not report if assignment is referenced in body" do
          expect_no_issues subject, <<-CRYSTAL
            def method(a)
              a = 2
            rescue
              a
            end
            CRYSTAL
        end

        it "doesn't report if assignment is referenced in ensure" do
          expect_no_issues subject, <<-CRYSTAL
            def method(a)
              a = 2
            ensure
              a
            end
            CRYSTAL
        end

        it "doesn't report if assignment is referenced in else" do
          expect_no_issues subject, <<-CRYSTAL
            def method(a)
              a = 2
            rescue
            else
              a
            end
            CRYSTAL
        end

        it "reports if assignment is useless" do
          expect_issue subject, <<-CRYSTAL
            def method(a)
            rescue
              a = 2
            # ^ error: Useless assignment to variable `a`
            end
            CRYSTAL
        end
      end
    end

    context "typeof" do
      it "reports useless assignments in typeof" do
        expect_issue subject, <<-CRYSTAL
          typeof(begin
            foo = 1
          # ^^^ error: Useless assignment to variable `foo`
            bar = 2
          # ^^^ error: Useless assignment to variable `bar`
          end)
          CRYSTAL
      end
    end

    context "macro" do
      it "doesn't report if assignment is referenced in macro" do
        expect_no_issues subject, <<-CRYSTAL
          def method
            a = 2
            {% if flag?(:bits64) %}
              a.to_s
            {% else %}
              a
            {% end %}
          end
          CRYSTAL
      end

      it "doesn't report referenced assignments in macro literal" do
        expect_no_issues subject, <<-CRYSTAL
          def method
            a = 2
            {% if flag?(:bits64) %}
              a = 3
            {% else %}
              a = 4
            {% end %}
            puts a
          end
          CRYSTAL
      end

      it "doesn't report if assignment is referenced in macro def" do
        expect_no_issues subject, <<-CRYSTAL
          macro macro_call
            puts x
          end

          def foo
            x = 1
            macro_call
          end
          CRYSTAL
      end

      it "doesn't report if assignment is referenced in a macro below" do
        expect_no_issues subject, <<-CRYSTAL
          class Foo
            def foo
              a = 1
              macro_call
            end

            macro macro_call
              puts a
            end
          end
          CRYSTAL
      end

      it "doesn't report if assignment is referenced in a macro expression as string" do
        expect_no_issues subject, <<-CRYSTAL
          foo = 1
          puts {{ "foo".id }}
          CRYSTAL
      end

      it "doesn't report if assignment is referenced in for macro in exp" do
        expect_no_issues subject, <<-CRYSTAL
          foo = 22

          {% for x in %w[foo] %}
            add({{ x.id }})
          {% end %}
          CRYSTAL
      end

      it "doesn't report if assignment is referenced in for macro in body" do
        expect_no_issues subject, <<-CRYSTAL
          foo = 22

          {% for x in %w[bar] %}
            puts {{ "foo".id }}
          {% end %}
          CRYSTAL
      end

      it "doesn't report if assignment is referenced in if macro in cond" do
        expect_no_issues subject, <<-CRYSTAL
          foo = 22

          {% if "foo".id %}
          {% end %}
          CRYSTAL
      end

      it "doesn't report if assignment is referenced in if macro in then" do
        expect_no_issues subject, <<-CRYSTAL
          foo = 22

          {% if true %}
             puts {{ "foo".id }}
          {% end %}
          CRYSTAL
      end

      it "doesn't report if assignment is referenced in if macro in else" do
        expect_no_issues subject, <<-CRYSTAL
          foo = 22

          {% if true %}
          {% else %}
             puts {{ "foo".id }}
          {% end %}
          CRYSTAL
      end
    end

    it "does not report if variable is referenced and there is a deep level scope" do
      expect_no_issues subject, <<-CRYSTAL
        response = JSON.build do |json|
          json.object do
            json.object do
              json.object do
                json.object do
                  json.object do
                    json.object do
                      json.object do
                        json.object do
                          json.object do
                            json.object do
                              json.object do
                                json.object do
                                  json.object do
                                    json.object do
                                      json.object do
                                        anything
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end

        response = JSON.parse(response)
        response
        CRYSTAL
    end

    context "type declaration" do
      it "reports if it's not referenced at a top level" do
        expect_issue subject, <<-CRYSTAL
          a : String?
          # ^^^^^^^^^ error: Useless assignment to variable `a`
          CRYSTAL
      end

      it "reports if it's not referenced in a method" do
        expect_issue subject, <<-CRYSTAL
          def foo
            a : String?
          # ^^^^^^^^^^^ error: Useless assignment to variable `a`
          end
          CRYSTAL
      end

      it "reports if it's not referenced in a class" do
        expect_issue subject, <<-CRYSTAL
          class Foo
            a : String?
          # ^^^^^^^^^^^ error: Useless assignment to variable `a`
          end
          CRYSTAL
      end

      it "doesn't report if it's referenced" do
        expect_no_issues subject, <<-CRYSTAL
          def foo
            a : String?
            a
          end
          CRYSTAL
      end
    end

    context "uninitialized" do
      it "reports if uninitialized assignment is not referenced at a top level" do
        expect_issue subject, <<-CRYSTAL
          a = uninitialized U
          # ^{} error: Useless assignment to variable `a`
          CRYSTAL
      end

      it "reports if uninitialized assignment is not referenced in a method" do
        expect_issue subject, <<-CRYSTAL
          def foo
            a = uninitialized U
          # ^ error: Useless assignment to variable `a`
          end
          CRYSTAL
      end

      it "doesn't report if uninitialized assignment is referenced" do
        expect_no_issues subject, <<-CRYSTAL
          def foo
            a = uninitialized U
            a
          end
          CRYSTAL
      end
    end
  end
end
