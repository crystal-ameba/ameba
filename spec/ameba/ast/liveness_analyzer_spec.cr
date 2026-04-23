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

      it "does not report assignment used after break" do
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
        dead_store_names(scope).should be_empty
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

      it "does not report assignment inside conditional break" do
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

    context "exception handlers" do
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
      end
    end

    context "multi assignments" do
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

      it "does not report multi-assign target used in next loop iteration" do
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
    end
  end
end
