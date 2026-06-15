require "../../spec_helper"

private def scopes_for(code)
  rule = Ameba::ScopeRule.new
  source = Ameba::Source.new(code)
  Ameba::AST::ScopeVisitor.new(rule, source)
  rule.scopes
end

private def reaches?(code, name)
  inner = scopes_for(code).find! do |scope|
    (scope.node.is_a?(Crystal::Block) || scope.node.is_a?(Crystal::ProcLiteral)) &&
      scope.arguments.any?(&.name.== name)
  end
  outer = inner.outer_scope || raise "expected an outer scope"
  outer.declared_at?(name, inner.node)
end

module Ameba::AST
  describe ReachingDefinitionAnalyzer do
    context "sequential flow" do
      it "reaches a block after the assignment" do
        reaches?(<<-CRYSTAL, "x").should be_true
          x = 1
          foo { |x| }
          CRYSTAL
      end

      it "does not reach a block before the assignment" do
        reaches?(<<-CRYSTAL, "x").should be_false
          foo { |x| }
          x = 1
          CRYSTAL
      end

      it "does not reach a block nested in its own initializing assignment" do
        reaches?(<<-CRYSTAL, "x").should be_false
          x = foo { |x| }
          CRYSTAL
      end

      it "reaches through a splat multi-assignment target" do
        reaches?(<<-CRYSTAL, "x").should be_true
          a, *x = [1, 2, 3]
          foo { |x| }
          CRYSTAL
      end

      it "reaches an assignment inside a short-circuit operator" do
        reaches?(<<-CRYSTAL, "x").should be_true
          done || (x = compute)
          foo { |x| }
          CRYSTAL
      end
    end

    context "conditional flow" do
      it "does not reach across mutually exclusive if/else branches" do
        reaches?(<<-CRYSTAL, "x").should be_false
          if cond
            x = 1
          else
            foo { |x| }
          end
          CRYSTAL
      end

      it "reaches when assigned before the conditional" do
        reaches?(<<-CRYSTAL, "x").should be_true
          x = 1
          if cond
            foo { |x| }
          end
          CRYSTAL
      end

      it "reaches when assigned in the condition" do
        reaches?(<<-CRYSTAL, "x").should be_true
          if x = compute
            foo { |x| }
          end
          CRYSTAL
      end

      it "may reach when assigned in only one prior branch" do
        reaches?(<<-CRYSTAL, "x").should be_true
          if cond
            x = 1
          end
          foo { |x| }
          CRYSTAL
      end
    end

    context "terminating branches" do
      it "does not reach past a branch that returns" do
        reaches?(<<-CRYSTAL, "x").should be_false
          def foo
            if cond
              x = 1
              return
            end
            bar { |x| }
          end
          CRYSTAL
      end

      it "does not reach past a branch that raises" do
        reaches?(<<-CRYSTAL, "x").should be_false
          def foo
            if cond
              x = 1
              raise "boom"
            end
            bar { |x| }
          end
          CRYSTAL
      end

      it "reaches when the terminating branch does not assign the variable" do
        reaches?(<<-CRYSTAL, "x").should be_true
          def foo
            x = 1
            return if cond
            bar { |x| }
          end
          CRYSTAL
      end

      it "reaches a block nested inside a terminating branch" do
        reaches?(<<-CRYSTAL, "x").should be_true
          def foo
            if cond
              x = 1
              bar { |x| }
              return
            end
          end
          CRYSTAL
      end
    end

    context "loops" do
      it "reaches a block assigned earlier in the same iteration" do
        reaches?(<<-CRYSTAL, "x").should be_true
          while cond
            x = 1
            foo { |x| }
          end
          CRYSTAL
      end

      it "reaches a block when assigned before the loop" do
        reaches?(<<-CRYSTAL, "x").should be_true
          x = 1
          while cond
            foo { |x| }
          end
          CRYSTAL
      end

      # Crystal scoping is lexical: a variable assigned later in the body is not
      # in scope at an earlier point, even though the loop's back edge would
      # reach it at runtime.
      it "does not reach a block that precedes the assignment in the body" do
        reaches?(<<-CRYSTAL, "x").should be_false
          while cond
            foo { |x| }
            x = 1
          end
          CRYSTAL
      end

      it "does not reach a block that precedes the assignment in an until body" do
        reaches?(<<-CRYSTAL, "x").should be_false
          until cond
            foo { |x| }
            x = 1
          end
          CRYSTAL
      end

      it "does not reach a block in a loop that never assigns the variable" do
        reaches?(<<-CRYSTAL, "x").should be_false
          while cond
            foo { |x| }
          end
          CRYSTAL
      end
    end

    context "captured definitions" do
      it "reaches through a nested block from an outer assignment" do
        reaches?(<<-CRYSTAL, "x").should be_true
          x = 1
          foo { bar { |x| } }
          CRYSTAL
      end

      it "treats arguments as reaching definitions" do
        reaches?(<<-CRYSTAL, "x").should be_true
          def foo(x)
            bar { |x| }
          end
          CRYSTAL
      end

      it "does not capture across a def boundary" do
        reaches?(<<-CRYSTAL, "x").should be_false
          x = 1
          def foo
            bar { |x| }
          end
          CRYSTAL
      end
    end
  end
end
