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

          -> (baz : Int32) { }
          -> (bar : String) { }
        end
        CRYSTAL
    end

    it "reports if there is a shadowing in a block" do
      expect_issue subject, <<-CRYSTAL
        def some_method
          foo = 1

          3.times do |foo|
                    # ^^^ error: Shadowing outer local variable `foo`
          end
        end
        CRYSTAL
    end

    pending "reports if there is a shadowing in an unpacked variable in a block" do
      expect_issue subject, <<-CRYSTAL
        def some_method
          foo = 1

          [{3}].each do |(foo)|
                        # ^^^ error: Shadowing outer local variable `foo`
          end
        end
        CRYSTAL
    end

    pending "reports if there is a shadowing in an unpacked variable in a block (2)" do
      expect_issue subject, <<-CRYSTAL
        def some_method
          foo = 1

          [{[3]}].each do |((foo))|
                           # ^^^ error: Shadowing outer local variable `foo`
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

          -> (foo : Int32) { }
            # ^^^ error: Shadowing outer local variable `foo`
        end
        CRYSTAL
    end

    it "reports if there is a shadowing in an inner scope" do
      expect_issue subject, <<-CRYSTAL
        def foo
          foo = 1

          3.times do |i|
            3.times { |foo| foo }
                     # ^^^ error: Shadowing outer local variable `foo`
          end
        end
        CRYSTAL
    end

    it "reports if variable is shadowed twice" do
      expect_issue subject, <<-CRYSTAL
        foo = 1

        3.times do |foo|
                  # ^^^ error: Shadowing outer local variable `foo`
          -> (foo : Int32) { foo + 1 }
            # ^^^ error: Shadowing outer local variable `foo`
        end
        CRYSTAL
    end

    it "reports if a splat block argument shadows local var" do
      expect_issue subject, <<-CRYSTAL
        foo = 1

        3.times do |*foo|
                   # ^^^ error: Shadowing outer local variable `foo`
        end
        CRYSTAL
    end

    it "reports if a &block argument is shadowed" do
      expect_issue subject, <<-CRYSTAL
        def method_with_block(a, &block)
          3.times do |block|
                    # ^^^^^ error: Shadowing outer local variable `block`
          end
        end
        CRYSTAL
    end

    it "reports if there are multiple args and one shadows local var" do
      expect_issue subject, <<-CRYSTAL
        foo = 1
        [1, 2, 3].each_with_index do |i, foo|
                                       # ^^^ error: Shadowing outer local variable `foo`
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

    context "block argument inside the introducing assignment" do
      it "does not report when block argument shares a name with the outer assignment target" do
        expect_no_issues subject, <<-CRYSTAL
          x = foo { |x| x + 1 }
          CRYSTAL
      end

      it "does not report when the block is nested inside the assignment value" do
        expect_no_issues subject, <<-CRYSTAL
          x = if cond
                1
              else
                foo { |x| x + 1 }
              end
          CRYSTAL
      end

      it "reports when the outer variable is already declared before the assignment" do
        expect_issue subject, <<-CRYSTAL
          x = 1
          x = foo { |x| x + 1 }
                   # ^ error: Shadowing outer local variable `x`
          CRYSTAL
      end

      it "reports when the outer variable is declared on a sibling statement" do
        expect_issue subject, <<-CRYSTAL
          x = 1
          foo { |x| x + 1 }
               # ^ error: Shadowing outer local variable `x`
          CRYSTAL
      end
    end

    # https://github.com/crystal-ameba/ameba/issues/819
    context "mutually exclusive branches" do
      it "does not report when assignment and block argument live in opposite if/else branches" do
        expect_no_issues subject, <<-CRYSTAL
          if rand > 0.5
            x = 1
          else
            [1, 2].each { |x| puts x }
          end
          CRYSTAL
      end

      it "does not report when assignment is in if-then and block is in elsif" do
        expect_no_issues subject, <<-CRYSTAL
          if a
            x = 1
          elsif b
            [1, 2].each { |x| puts x }
          end
          CRYSTAL
      end

      it "does not report when assignment and block are in different unless branches" do
        expect_no_issues subject, <<-CRYSTAL
          unless cond
            x = 1
          else
            [1, 2].each { |x| puts x }
          end
          CRYSTAL
      end

      it "does not report when assignment and block are in different case whens" do
        expect_no_issues subject, <<-CRYSTAL
          case value
          when 1
            x = 1
          when 2
            [1, 2].each { |x| puts x }
          end
          CRYSTAL
      end

      it "does not report when assignment is in case-when and block is in case-else" do
        expect_no_issues subject, <<-CRYSTAL
          case value
          when 1
            x = 1
          else
            [1, 2].each { |x| puts x }
          end
          CRYSTAL
      end

      it "does not report when branches are nested and still mutually exclusive" do
        expect_no_issues subject, <<-CRYSTAL
          if outer
            if inner
              x = 1
            else
              [1, 2].each { |x| puts x }
            end
          end
          CRYSTAL
      end

      it "reports when assignment dominates the block (no mutual exclusion)" do
        expect_issue subject, <<-CRYSTAL
          x = 1
          if cond
            [1, 2].each do |x|
                          # ^ error: Shadowing outer local variable `x`
              puts x
            end
          end
          CRYSTAL
      end

      it "reports when assignment is in same branch as block" do
        expect_issue subject, <<-CRYSTAL
          if cond
            x = 1
            [1, 2].each do |x|
                          # ^ error: Shadowing outer local variable `x`
              puts x
            end
          end
          CRYSTAL
      end

      it "reports when assignment is in if-condition (runs regardless of branch)" do
        expect_issue subject, <<-CRYSTAL
          if x = compute
            puts x
          else
            [1, 2].each do |x|
                          # ^ error: Shadowing outer local variable `x`
              puts x
            end
          end
          CRYSTAL
      end

      it "reports when any assignment can reach the block argument" do
        expect_issue subject, <<-CRYSTAL
          x = 1
          if cond
            x = 2
          else
            [1, 2].each do |x|
                          # ^ error: Shadowing outer local variable `x`
              puts x
            end
          end
          CRYSTAL
      end

      it "does not report when assignment and block live in different rescue branches" do
        expect_no_issues subject, <<-CRYSTAL
          begin
            raise "x"
          rescue ArgumentError
            x = 1
          rescue
            [1, 2].each { |x| puts x }
          end
          CRYSTAL
      end

      it "does not report when assignment is in a rescue and block is in the else branch" do
        expect_no_issues subject, <<-CRYSTAL
          begin
            raise "x"
          rescue
            x = 1
          else
            [1, 2].each { |x| puts x }
          end
          CRYSTAL
      end

      it "reports when assignment in body can reach a rescue's block argument" do
        expect_issue subject, <<-CRYSTAL
          begin
            x = 1
          rescue
            [1, 2].each do |x|
                          # ^ error: Shadowing outer local variable `x`
              puts x
            end
          end
          CRYSTAL
      end

      it "does not report when assignment and block live in different select whens" do
        expect_no_issues subject, <<-CRYSTAL
          select
          when v = ch1.receive
            x = v
          when ch2.receive
            [1, 2].each { |x| puts x }
          end
          CRYSTAL
      end

      it "does not report when proc argument is in a mutually exclusive branch" do
        expect_no_issues subject, <<-CRYSTAL
          if rand > 0.5
            x = 1
          else
            -> (x : Int32) { x + 1 }
          end
          CRYSTAL
      end
    end

    context "multi-assignment and short-circuit operators" do
      it "reports when a splat multi-assignment target is shadowed" do
        expect_issue subject, <<-CRYSTAL
          a, *foo = [1, 2, 3]
          bar { |foo| foo }
               # ^^^ error: Shadowing outer local variable `foo`
          CRYSTAL
      end

      it "reports when an assignment inside a short-circuit operator is shadowed" do
        expect_issue subject, <<-CRYSTAL
          done || (foo = compute)
          bar { |foo| foo }
               # ^^^ error: Shadowing outer local variable `foo`
          CRYSTAL
      end
    end

    context "unconnected (terminating) code branch" do
      it "does not report when the assignment branch ends in `return`" do
        expect_no_issues subject, <<-CRYSTAL
          def foo
            if cond
              x = 1
              return
            end

            bar { |x| x + 1 }
          end
          CRYSTAL
      end

      it "does not report when the assignment branch ends in `next`" do
        expect_no_issues subject, <<-CRYSTAL
          [1, 2].each do |i|
            if cond
              x = 1
              next
            end

            bar { |x| x + 1 }
          end
          CRYSTAL
      end

      it "does not report when the assignment branch ends in `break`" do
        expect_no_issues subject, <<-CRYSTAL
          [1, 2].each do |i|
            if cond
              x = 1
              break
            end

            bar { |x| x + 1 }
          end
          CRYSTAL
      end

      it "does not report when the assignment branch ends in `raise`" do
        expect_no_issues subject, <<-CRYSTAL
          def foo
            if cond
              x = 1
              raise "boom"
            end

            bar { |x| x + 1 }
          end
          CRYSTAL
      end

      it "does not report when every branch of the assignment is terminating" do
        expect_no_issues subject, <<-CRYSTAL
          def foo
            if cond
              x = 1
              return x
            else
              x = 2
              return x
            end

            bar { |x| x + 1 }
          end
          CRYSTAL
      end

      it "reports when the terminating branch does not assign the variable" do
        expect_issue subject, <<-CRYSTAL
          def foo
            x = 1
            return if cond

            bar { |x| x + 1 }
                 # ^ error: Shadowing outer local variable `x`
          end
          CRYSTAL
      end

      it "reports when the assignment is reachable past a nested non-terminating branch" do
        expect_issue subject, <<-CRYSTAL
          def foo
            if cond
              return if other
              x = 1
            end

            bar { |x| x + 1 }
                 # ^ error: Shadowing outer local variable `x`
          end
          CRYSTAL
      end
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
