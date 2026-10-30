require "../../spec_helper"

private def scopes_for(code)
  rule = Ameba::ScopeRule.new
  source = Ameba::Source.new(code)
  Ameba::AST::ScopeVisitor.new(rule, source)
  rule.scopes
end

private def top_scope(code)
  scopes_for(code).find!(&.node.is_a?(Crystal::Expressions))
end

private def def_scope(code)
  scopes_for(code).find!(&.node.is_a?(Crystal::Def))
end

private def block_scope(code)
  scopes_for(code).find!(&.node.is_a?(Crystal::Block))
end

private def dead_store_names(scope)
  Ameba::AST::LivenessAnalyzer.new(scope).dead_stores.map(&.variable.name)
end

module Ameba::AST
  describe LivenessAnalyzer do
    context "basic assignments" do
      it "detects unused assignment as dead store" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 1
          end
          CRYSTAL
        dead_store_names(scope).should eq ["a"]
      end

      it "does not report assignment that is used" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 1
            a
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "detects first assignment as dead when overwritten before use" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 1
            a = 2
            a
          end
          CRYSTAL
        dead_store_names(scope).should eq ["a"]
      end

      it "detects all assignments as dead when none are used" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 1
            a = 2
          end
          CRYSTAL
        dead_store_names(scope).should eq ["a", "a"]
      end

      it "does not report assignment used in a condition" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 1
            if a
              nil
            end
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "reports second assignment when value is not used" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 1
            a = a + 1
          end
          CRYSTAL
        dead_store_names(scope).should eq ["a"]
      end

      it "does not report assignment used in another assignment" do
        scope = def_scope <<-CRYSTAL
          def foo
            if f = get_something
              @f = f
            end
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "reports last assignment when not used after reassignment" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 1
            puts a
            a = 2
          end
          CRYSTAL
        dead_store_names(scope).should eq ["a"]
      end
    end

    context "op assignments" do
      it "does not report op-assign when result is used" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 1
            a += 1
            a
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "reports op-assign when result is not used" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 1
            a += 1
          end
          CRYSTAL
        dead_store_names(scope).should eq ["a"]
      end

      it "does not report chained op-assigns when result is used" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 1
            a += 1
            a += 1
            a = a + 1
            a
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end
    end

    context "if/unless branches" do
      it "reports initial assignment as dead when overwritten in both branches" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 0
            if something
              a = 1
            else
              a = 2
            end
            a
          end
          CRYSTAL
        dead_store_names(scope).should eq ["a"]
      end

      it "does not report when assigned in one branch and used after" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 0
            if something
              a = 1
            end
            a
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not report when assigned in one branch with else nil and used after" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 0
            if something
              a = 1
            else
              nil
            end
            a
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "reports useless assignment in branch when not used after" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
            if a
              a = 2
            end
          end
          CRYSTAL
        dead_store_names(scope).should eq ["a"]
      end

      it "reports first dead assignment in branch when overwritten" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
            a = 1
            if a
              a = 2
              a = 3
            end
            a
          end
          CRYSTAL
        dead_store_names(scope).should eq ["a"]
      end

      it "reports initial assignment as dead when overwritten in all branches" do
        scope = def_scope <<-CRYSTAL
          def foo
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
        dead_store_names(scope).should eq ["has_newline"]
      end

      it "does not report unless with consumed branches" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 0
            unless something
              a = 1
            else
              a = 2
            end
            a
          end
          CRYSTAL
        dead_store_names(scope).should eq ["a"]
      end

      it "reports dead assignment in unless branch" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 0
            unless something
              a = 1
              a = 2
            else
              a = 2
            end
            a
          end
          CRYSTAL
        dead_store_names(scope).should eq ["a", "a"]
      end

      it "does not report one-line if assignment used after" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 0
            a = 1 if something
            a
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end
    end

    context "while loops" do
      it "does not report assignment used across iterations" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
            while a < 10
              a = a + 1
            end
            a
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "reports assignment not used outside loop" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
            while a < 10
              b = a
            end
          end
          CRYSTAL
        dead_store_names(scope).should eq ["b"]
      end

      it "does not report assignment used in loop with accumulator" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 3
            result = 0

            while result < 10
              result += a
              a = a + 1
            end
            result
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not report parameter assignment used in loop" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
            result = 0

            while result < 10
              result += a
              a = a + 1
            end
            result
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not report assignment in loop with inner branch" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
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
        dead_store_names(scope).should be_empty
      end

      it "handles branch with blank node in loop" do
        scope = def_scope <<-CRYSTAL
          def foo
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
        dead_store_names(scope).should be_empty
      end

      it "reports assignment overwritten before the only break of infinite loop" do
        scope = def_scope <<-CRYSTAL
          def foo
            found = false
            while true
              if something
                found = true
                break
              end
            end
            found
          end
          CRYSTAL
        dead_store_names(scope).should eq ["found"]
      end

      it "does not report assignment used after break" do
        scope = def_scope <<-CRYSTAL
          def foo
            found = false
            while true
              break if something
              found = true
            end
            found
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not report assignment used after conditional loop" do
        scope = def_scope <<-CRYSTAL
          def foo
            found = false
            while something
              if other
                found = true
                break
              end
            end
            found
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "reports assignment read only after infinite until loop" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 1
            until false
              process
            end
            a
          end
          CRYSTAL
        dead_store_names(scope).should eq ["a"]
      end

      it "does not report assignment before next used in subsequent iteration" do
        scope = def_scope <<-CRYSTAL
          def foo
            atomic = parse_atomic
            while true
              if @token.instance_var?
                atomic = parse_ivar(atomic)
                next
              end
              break
            end
            atomic
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not report assignment used after break in nested loops" do
        scope = def_scope <<-CRYSTAL
          def foo
            found = false
            while outer_cond
              while inner_cond
                if something
                  found = true
                  break
                end
              end
            end
            found
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "reports initializer overwritten inside conditional break, but not the latter" do
        scope = def_scope <<-CRYSTAL
          def foo
            options = 0
            while true
              if done?
                options = compute_options
                break
              end
              process
            end
            options
          end
          CRYSTAL
        dead_store_names(scope).should eq ["options"]
      end

      it "does not report assignment read by the condition after next" do
        scope = def_scope <<-CRYSTAL
          def foo
            x = 0
            while x < 10
              x = 1
              next if bar
              x = 2
            end
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end
    end

    context "until loops" do
      it "does not report assignment used across until iterations" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
            until a > 10
              a = a + 1
            end
            a
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "reports useless assignment in until loop" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
            until a > 10
              b = a + 1
            end
          end
          CRYSTAL
        dead_store_names(scope).should eq ["b"]
      end
    end

    context "calls never returning" do
      it "reports assignment read only after raise" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 1
            raise "x"
            a
          end
          CRYSTAL
        dead_store_names(scope).should eq ["a"]
      end

      it "reports assignment read only after exit / abort" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 1
            exit 1
            a
          end
          CRYSTAL
        dead_store_names(scope).should eq ["a"]

        scope = def_scope <<-CRYSTAL
          def foo
            a = 1
            abort "x"
            a
          end
          CRYSTAL
        dead_store_names(scope).should eq ["a"]
      end

      it "does not report assignment read by the raise arguments" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 1
            raise a.to_s
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not report assignment read in rescue after raise" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 1
            raise "x"
            a
          rescue
            a
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not report assignment read in ensure after raise" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 1
            raise "x"
          ensure
            a
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not report assignment read after raise in a branch" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 1
            raise "x" if something
            a
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not treat raise with a receiver as never returning" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 1
            obj.raise "x"
            a
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end
    end

    context "exception handlers" do
      it "treats the rescue variable as assigned on entering the rescue branch" do
        scope = def_scope <<-CRYSTAL
          def foo
            raise "x"
          rescue ex
          end
          CRYSTAL
        dead_store_names(scope).should eq ["ex"]
      end

      it "does not report the rescue variable used after the handler" do
        scope = def_scope <<-CRYSTAL
          def foo
            begin
              raise "x"
            rescue ex
            end
            ex
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "treats the argument as overwritten by the rescue variable" do
        scope = def_scope <<-CRYSTAL
          def foo(ex)
            raise "x"
          rescue ex
            ex
          end
          CRYSTAL
        LivenessAnalyzer.new(scope).entry_live_set.should_not contain("ex")
      end

      it "does not report assignment used in rescue" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
            a = 2
          rescue
            a
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not report assignment used in ensure" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
            a = 2
          ensure
            a
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not report assignment used in else" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
            a = 2
          rescue
          else
            a
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "reports useless assignment in rescue" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
          rescue
            a = 2
          end
          CRYSTAL
        dead_store_names(scope).should eq ["a"]
      end

      it "does not report assignment used in rescue when body has return" do
        scope = def_scope <<-CRYSTAL
          def foo
            start = 1
            begin
              perform_foo
              return
            rescue
              start
            end
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not report assignment used in rescue when body has break" do
        scope = block_scope <<-CRYSTAL
          3.times do
            start = 1
            begin
              perform_foo
              break
            rescue
              start
            end
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not report assignment used in rescue when body has next" do
        scope = block_scope <<-CRYSTAL
          3.times do
            start = 1
            begin
              perform_foo
              next
            rescue
              start
            end
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not report assignment followed by a raising call and used in rescue" do
        scope = def_scope <<-CRYSTAL
          def foo
            begin
              x = 1
              bar
              x = 2
            rescue
              x
            end
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not report assignment followed by a raising call and used in outer rescue" do
        scope = def_scope <<-CRYSTAL
          def foo
            begin
              begin
                x = 1
                bar
                x = 2
              ensure
                baz
              end
            rescue
              x
            end
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not report assignment followed by a raising call and used in ensure" do
        scope = def_scope <<-CRYSTAL
          def foo
            begin
              x = 1
              bar
              x = 2
            ensure
              x
            end
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not report assignment followed by a yield and used in rescue" do
        scope = def_scope <<-CRYSTAL
          def foo
            x = 1
            yield
            x = 2
          rescue
            x
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not report assignment followed by a cast and used in rescue" do
        scope = def_scope <<-CRYSTAL
          def foo(y)
            x = 1
            y.as(Int32)
            x = 2
          rescue
            x
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "reports assignment overwritten before any raising call" do
        scope = def_scope <<-CRYSTAL
          def foo
            begin
              x = 1
              x = 2
              bar
            rescue
              x
            end
          end
          CRYSTAL
        dead_store_names(scope).should eq ["x"]
      end

      it "does not report assignment followed by an op-assignment and used in rescue" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
            x = 1
            a += 1
            x = 2
            a
          rescue
            x
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not report assignment followed by a multi-assignment of a single value and used in rescue" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
            x = 1
            b, c = a
            x = 2
            b + c
          rescue
            x
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not report assignment followed by a string interpolation and used in rescue" do
        scope = def_scope <<-'CRYSTAL'
          def foo(a)
            x = 1
            b = "#{a}"
            x = 2
            b
          rescue
            x
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not report assignment followed by a macro expansion and used in rescue" do
        scope = def_scope <<-CRYSTAL
          def foo
            x = 1
            {% if flag?(:foo) %}
              bar
            {% end %}
            x = 2
          rescue
            x
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "reports assignment followed by a logical op-assignment and overwritten" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
            begin
              x = 1
              a ||= 1
              x = 2
              bar(a)
            rescue
              x
            end
          end
          CRYSTAL
        dead_store_names(scope).should eq ["x"]
      end

      it "does not report assignment in ensure read after next" do
        scope = def_scope <<-CRYSTAL
          def foo
            x = 0
            while x < 10
              begin
                next if bar
              ensure
                x = 1
              end
              x = 2
            end
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "reports assignment in ensure overwritten on every exit" do
        scope = def_scope <<-CRYSTAL
          def foo
            begin
              bar
            ensure
              x = 1
            end
            x = 2
            x
          end
          CRYSTAL
        dead_store_names(scope).should eq ["x"]
      end
    end

    context "binary operators" do
      it "does not report when both sides of && are used" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
            (a = 1) && (b = 1)
            a + b
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "reports unused side of ||" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
            (a = 1) || (b = 1)
            a
          end
          CRYSTAL
        dead_store_names(scope).should eq ["b"]
      end
    end

    context "case" do
      it "does not report when used after case" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
            case a
            when /foo/
              a = 1
            when /bar/
              a = 2
            end
            puts a
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "reports when not used after case" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
            case a
            when /foo/
              a = 1
            when /bar/
              a = 2
            end
          end
          CRYSTAL
        dead_store_names(scope).should eq ["a", "a"]
      end

      it "does not report assignment used in case condition" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 2
            case a
            when /foo/
            end
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      context "select" do
        it "does not report assignment used in a branch other than the one overwriting it" do
          scope = def_scope <<-CRYSTAL
            def foo(a, b)
              v = nil
              select
              when v = a.receive
                v
              when b.receive
                v
              end
            end
            CRYSTAL
          dead_store_names(scope).should be_empty
        end

        it "reports assignment in when condition not used in its branch" do
          scope = def_scope <<-CRYSTAL
            def foo(a, b)
              select
              when v = a.receive
              when b.receive
              end
            end
            CRYSTAL
          dead_store_names(scope).should eq ["v"]
        end
      end

      context "when" do
        it "does not report when assignment in when condition is used" do
          scope = def_scope <<-CRYSTAL
            def foo(a)
              case
              when a = foo_call
              when a = bar_call
              end
              puts a
            end
            CRYSTAL
          dead_store_names(scope).should be_empty
        end

        it "reports when assignment in when condition is not used" do
          scope = def_scope <<-CRYSTAL
            def foo(a)
              case
              when a = foo_call
              when a = bar_call
              end
            end
            CRYSTAL
          dead_store_names(scope).should eq ["a", "a"]
        end

        it "does not report assignment in when condition used in a subsequent branch" do
          scope = def_scope <<-CRYSTAL
            def foo(a)
              case a
              when (b = bar)
                1
              when 2
                b
              end
            end
            CRYSTAL
          dead_store_names(scope).should be_empty
        end

        it "reports assignment in when condition used only in a preceding branch" do
          scope = def_scope <<-CRYSTAL
            def foo(a)
              case a
              when 1
                b
              when (b = bar)
                2
              end
            end
            CRYSTAL
          dead_store_names(scope).should eq ["b"]
        end
      end
    end

    context "multi assignments" do
      it "reports unused multi-assign splat target" do
        scope = def_scope <<-CRYSTAL
          def foo
            a, *b = 1, 2, 3
            a
          end
          CRYSTAL
        dead_store_names(scope).should eq ["b"]
      end

      it "does not report when all targets are used" do
        scope = def_scope <<-CRYSTAL
          def foo
            a, b = {1, 2}
            a + b
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "reports unused multi-assign target" do
        scope = def_scope <<-CRYSTAL
          def foo
            a, b = {1, 2}
            a
          end
          CRYSTAL
        dead_store_names(scope).should eq ["b"]
      end

      it "reports all unused multi-assign targets" do
        scope = def_scope <<-CRYSTAL
          def foo
            a, b = {1, 2}
          end
          CRYSTAL
        dead_store_names(scope).should eq ["b", "a"]
      end

      it "reports reassigned multi-assign targets" do
        scope = def_scope <<-CRYSTAL
          def foo
            a, b = {1, 2}
            a, b = {3, 4}
          end
          CRYSTAL
        dead_store_names(scope).should eq ["b", "a", "b", "a"]
      end

      it "reports multi-assign target overwritten at loop start" do
        scope = def_scope <<-CRYSTAL
          def foo
            while true
              word = get_word
              if (word & 0xFF) == 0
                word, success = compare_and_set(word, word + 1)
                return if success
              end
            end
          end
          CRYSTAL
        dead_store_names(scope).should eq ["word"]
      end

      it "reports multi-assign target read only after infinite loop" do
        scope = def_scope <<-CRYSTAL
          def foo
            while true
              word = get_word
              if (word & 0xFF) == 0
                word, success = compare_and_set(word, word + 1)
                if success
                  return
                end
              else
                puts word
              end
            end
            word
          end
          CRYSTAL
        dead_store_names(scope).should eq ["word"]
      end

      it "does not report assignment read by a call target" do
        scope = def_scope <<-CRYSTAL
          def foo
            obj = Foo.new
            obj.x, y = 1, 2
            y
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not report assignment read by an index target" do
        scope = def_scope <<-CRYSTAL
          def foo(arr)
            i = 1
            arr[i], *rest = [1, 2, 3]
            rest
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end
    end

    context "out arguments" do
      it "reports assignment overwritten by an out argument" do
        scope = def_scope <<-CRYSTAL
          def foo
            x = 1
            LibC.bar(out x)
            x
          end
          CRYSTAL
        dead_store_names(scope).should eq ["x"]
      end

      it "does not report unused out argument" do
        scope = def_scope <<-CRYSTAL
          def foo
            LibC.bar(out x)
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end
    end

    context "top level scope" do
      it "detects dead stores at top level" do
        scope = top_scope <<-CRYSTAL
          a = 1
          a = 2
          CRYSTAL
        dead_store_names(scope).should eq ["a", "a"]
      end

      it "does not report referenced top-level assignments" do
        scope = top_scope <<-CRYSTAL
          a = 1
          a += 1
          a
          CRYSTAL
        dead_store_names(scope).should be_empty
      end
    end

    context "type declarations" do
      it "does not report unused type declaration without value" do
        scope = def_scope <<-CRYSTAL
          def foo
            a : String?
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "reports unused type declaration with value" do
        scope = def_scope <<-CRYSTAL
          def foo
            a : String? = "foo"
          end
          CRYSTAL
        dead_store_names(scope).should eq ["a"]
      end

      it "does not report used type declaration" do
        scope = def_scope <<-CRYSTAL
          def foo
            a : String?
            a
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not report assignment read by an instance variable type declaration" do
        scope = def_scope <<-CRYSTAL
          def initialize
            a = 1
            @b : Int32 = a
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end
    end

    context "uninitialized" do
      it "reports unused uninitialized assignment" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = uninitialized UInt8
          end
          CRYSTAL
        dead_store_names(scope).should eq ["a"]
      end

      it "does not report used uninitialized assignment" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = uninitialized UInt8
            a
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end
    end
    context "super and previous_def" do
      it "treats bare super as reading all arguments" do
        scope = def_scope <<-CRYSTAL
          def foo(a, b)
            a = super
            a
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "treats bare previous_def as reading all arguments" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
            a = previous_def
            a
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not treat super() with parens as reading arguments" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
            b = super()
          end
          CRYSTAL
        dead_store_names(scope).should eq ["b"]
      end

      it "does not treat super with explicit args as reading all arguments" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
            b = super(1)
          end
          CRYSTAL
        dead_store_names(scope).should eq ["b"]
      end

      it "does not report assignment read in a block of bare super" do
        scope = def_scope <<-CRYSTAL
          def foo
            x = 1
            super { puts x }
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end

      it "does not report assignment passed as a block argument of bare super" do
        scope = def_scope <<-CRYSTAL
          def foo
            blk = ->(i : Int32) { i }
            super &blk
          end
          CRYSTAL
        dead_store_names(scope).should be_empty
      end
    end

    context "inner scopes" do
      it "treats variables referenced in a block as read at its location" do
        scope = def_scope <<-CRYSTAL
          def foo
            a = 1
            [1].each { puts a }
            a = 2
          end
          CRYSTAL
        dead_store_names(scope).should eq ["a"]
      end

      it "treats bare super in a block as reading all arguments at its location" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
            a = 1
            [1].each { [2].each { super } }
          end
          CRYSTAL
        analyzer = LivenessAnalyzer.new(scope)
        analyzer.dead_stores.should be_empty
        analyzer.entry_live_set.should_not contain("a")
      end

      it "treats arguments as live at entry if read in a block before reassignment" do
        scope = def_scope <<-CRYSTAL
          def foo(a)
            [1].each { super }
            a = 1
            a
          end
          CRYSTAL
        LivenessAnalyzer.new(scope).entry_live_set.should contain("a")
      end
    end
  end
end
