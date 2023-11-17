require "../../../spec_helper"

module Ameba::Rule::Lint
  describe ShadowingOuterLocalVar do
    subject = ShadowingOuterLocalVar.new

    it "doesn't report if there is no shadowing" do
      expect_no_issues subject, <<-CRYSTAL
        def some_method
          foo = 1

          3.times do |bar|
            bar
          end

          -> (baz : Int32) {}
          -> (bar : String) {}
        end
        CRYSTAL
    end

    it "reports if there is a shadowing in a block" do
      expect_issue subject, <<-CRYSTAL
        def some_method
          foo = 1

          3.times do |foo|
                    # ^ error: Shadowing outer local variable `foo`
          end
        end
        CRYSTAL
    end

    pending "reports if there is a shadowing in an unpacked variable in a block" do
      expect_issue subject, <<-CRYSTAL
        def some_method
          foo = 1

          [{3}].each do |(foo)|
                        # ^ error: Shadowing outer local variable `foo`
          end
        end
        CRYSTAL
    end

    pending "reports if there is a shadowing in an unpacked variable in a block (2)" do
      expect_issue subject, <<-CRYSTAL
        def some_method
          foo = 1

          [{[3]}].each do |((foo))|
                           # ^ error: Shadowing outer local variable `foo`
          end
        end
        CRYSTAL
    end

    it "does not report outer vars declared below shadowed block" do
      expect_no_issues subject, <<-CRYSTAL
        methods = klass.methods.select { |m| m.annotation(MyAnn) }
        m = methods.last
        CRYSTAL
    end

    it "reports if there is a shadowing in a proc" do
      expect_issue subject, <<-CRYSTAL
        def some_method
          foo = 1

          -> (foo : Int32) {}
            # ^^^^^^^^^^^ error: Shadowing outer local variable `foo`
        end
        CRYSTAL
    end

    it "reports if there is a shadowing in an inner scope" do
      expect_issue subject, <<-CRYSTAL
        def foo
          foo = 1

          3.times do |i|
            3.times { |foo| foo }
                     # ^ error: Shadowing outer local variable `foo`
          end
        end
        CRYSTAL
    end

    it "reports if variable is shadowed twice" do
      expect_issue subject, <<-CRYSTAL
        foo = 1

        3.times do |foo|
                  # ^ error: Shadowing outer local variable `foo`
          -> (foo : Int32) { foo + 1 }
            # ^^^^^^^^^^^ error: Shadowing outer local variable `foo`
        end
        CRYSTAL
    end

    it "reports if a splat block argument shadows local var" do
      expect_issue subject, <<-CRYSTAL
        foo = 1

        3.times do |*foo|
                   # ^ error: Shadowing outer local variable `foo`
        end
        CRYSTAL
    end

    it "reports if a &block argument is shadowed" do
      expect_issue subject, <<-CRYSTAL
        def method_with_block(a, &block)
          3.times do |block|
                    # ^ error: Shadowing outer local variable `block`
          end
        end
        CRYSTAL
    end

    it "reports if there are multiple args and one shadows local var" do
      expect_issue subject, <<-CRYSTAL
        foo = 1
        [1, 2, 3].each_with_index do |i, foo|
                                       # ^ error: Shadowing outer local variable `foo`
          i + foo
        end
        CRYSTAL
    end

    it "doesn't report if an outer var is reassigned in a block" do
      expect_no_issues subject, <<-CRYSTAL
        def foo
          foo = 1
          3.times do |i|
            foo = 2
          end
        end
        CRYSTAL
    end

    it "doesn't report if an argument is a black hole '_'" do
      expect_no_issues subject, <<-CRYSTAL
        _ = 1
        3.times do |_|
        end
        CRYSTAL
    end

    it "doesn't report if it shadows record type declaration" do
      expect_no_issues subject, <<-CRYSTAL
        class FooBar
          record Foo, index : String

          def bar
            3.times do |index|
            end
          end
        end
        CRYSTAL
    end

    it "doesn't report if it shadows type declaration" do
      expect_no_issues subject, <<-CRYSTAL
        class FooBar
          getter index : String

          def bar
            3.times do |index|
            end
          end
        end
        CRYSTAL
    end

    it "doesn't report if it shadows throwaway arguments" do
      expect_no_issues subject, <<-CRYSTAL
        data = [{1, "a"}, {2, "b"}, {3, "c"}]

        data.each do |_, string|
          data.each do |number, _|
            puts string, number
          end
        end
        CRYSTAL
    end

    it "does not report if argument shadows an ivar assignment" do
      expect_no_issues subject, <<-CRYSTAL
        def bar(@foo)
          @foo.try do |foo|
          end
        end
        CRYSTAL
    end

    context "macro" do
      it "does not report shadowed vars in outer scope" do
        expect_no_issues subject, <<-CRYSTAL
          macro included
            def foo
              {% for ivar in instance_vars %}
                {% ann = ivar.annotation(Name) %}
              {% end %}
            end

            def bar
              {% instance_vars.reject { |ivar| ivar } %}
            end
          end
          CRYSTAL
      end

      it "does not report shadowed vars in macro within the same scope" do
        expect_no_issues subject, <<-CRYSTAL
          {% methods = klass.methods.select { |m| m.annotation(MyAnn) } %}

          {% for m, m_idx in methods %}
            {% if d = m.annotation(MyAnn) %}
              {% d %}
            {% end %}
          {% end %}
          CRYSTAL
      end

      it "does not report shadowed vars within nested macro" do
        expect_no_issues subject, <<-CRYSTAL
          module Foo
            macro included
              def foo
                {% for ann in instance_vars %}
                  {% pos_args = ann.args.empty? ? "Tuple.new".id : ann.args %}
                {% end %}
              end

              def bar
                {{
                  @type.instance_vars.map do |ivar|
                    ivar.annotations(Name).each do |ann|
                      puts ann.args
                    end
                  end
                }}
              end
            end
          end
          CRYSTAL
      end

      it "does not report scoped vars to MacroFor" do
        expect_no_issues subject, <<-CRYSTAL
          struct Test
            def test
              {% for ivar in @type.instance_vars %}
                {% var_type = ivar %}
              {% end %}

              {% ["a", "b"].map { |ivar| puts ivar } %}
            end
          end
          CRYSTAL
      end

      # https://github.com/crystal-ameba/ameba/issues/224#issuecomment-822245167
      it "does not report scoped vars to MacroFor (2)" do
        expect_no_issues subject, <<-CRYSTAL
          struct Test
            def test
              {% begin %}
                {% for ivar in @type.instance_vars %}
                  {% var_type = ivar %}
                {% end %}

                {% ["a", "b"].map { |ivar| puts ivar } %}
              {% end %}
            end
          end
          CRYSTAL
      end
    end
  end
end
