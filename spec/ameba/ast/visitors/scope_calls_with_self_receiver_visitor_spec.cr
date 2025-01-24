require "../../../spec_helper"

module Ameba::AST
  describe ScopeCallsWithSelfReceiverVisitor do
    {% for type in %w[class module].map(&.id) %}
      it "creates a scope for the {{ type }} def" do
        rule = SelfCallsRule.new
        visitor = ScopeCallsWithSelfReceiverVisitor.new rule, Source.new <<-CRYSTAL
          {{ type }} Foo
            self.foo
          end
          CRYSTAL

        call_queue = visitor.scope_call_queue
        call_queue.size.should eq 1
        call_queue.should eq rule.call_queue

        scope, calls = call_queue.first

        node = scope.node.should be_a(Crystal::{{ type.capitalize }}Def)
        node.name.should be_a(Crystal::Path)
        node.name.to_s.should eq "Foo"

        calls.size.should eq 1
        calls.first.name.should eq "foo"
      end
    {% end %}

    it "creates a scope for the def" do
      rule = SelfCallsRule.new
      visitor = ScopeCallsWithSelfReceiverVisitor.new rule, Source.new <<-CRYSTAL
        class Foo
          def method
            self.foo :a, :b, :c
            self.bar
            baz :x, :y, :z
            it_is_a.bat "country"
            self
          end
        end
        CRYSTAL

      call_queue = visitor.scope_call_queue
      call_queue.size.should eq 1
      call_queue.should eq rule.call_queue

      scope, calls = call_queue.first

      node = scope.node.should be_a(Crystal::Def)
      node.name.should eq "method"

      calls.size.should eq 2
      calls.first.name.should eq "foo"
      calls.last.name.should eq "bar"
    end

    it "creates a scope for the proc" do
      rule = SelfCallsRule.new
      visitor = ScopeCallsWithSelfReceiverVisitor.new rule, Source.new <<-CRYSTAL
        -> { self.foo }
        CRYSTAL

      call_queue = visitor.scope_call_queue
      call_queue.size.should eq 1
      call_queue.should eq rule.call_queue
    end

    it "creates a scope for the block" do
      rule = SelfCallsRule.new
      visitor = ScopeCallsWithSelfReceiverVisitor.new rule, Source.new <<-CRYSTAL
        3.times { self.foo }
        CRYSTAL

      call_queue = visitor.scope_call_queue
      call_queue.size.should eq 1
      call_queue.should eq rule.call_queue
    end

    context "inner scopes" do
      it "creates scope for block inside def" do
        rule = SelfCallsRule.new
        visitor = ScopeCallsWithSelfReceiverVisitor.new rule, Source.new <<-CRYSTAL
          def method
            self.foo
            3.times { self.bar }
          end
          CRYSTAL

        call_queue = visitor.scope_call_queue
        call_queue.size.should eq 2
        call_queue.should eq rule.call_queue
        call_queue.last_key.outer_scope.should eq call_queue.first_key
      end

      it "creates scope for block inside block" do
        rule = SelfCallsRule.new
        visitor = ScopeCallsWithSelfReceiverVisitor.new rule, Source.new <<-CRYSTAL
          def method
            3.times do
              self.bar
              2.times { self.baz }
            end
          end
          CRYSTAL

        call_queue = visitor.scope_call_queue
        call_queue.size.should eq 2
        call_queue.should eq rule.call_queue
        call_queue.last_key.outer_scope.should eq call_queue.first_key
      end
    end
  end
end
