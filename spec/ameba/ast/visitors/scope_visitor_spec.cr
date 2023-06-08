require "../../../spec_helper"

module Ameba::AST
  describe ScopeVisitor do
    {% for type in %w[class module enum].map(&.id) %}
      it "creates a scope for the {{ type }} def" do
        rule = ScopeRule.new
        ScopeVisitor.new rule, Source.new <<-CRYSTAL
          {{ type }} Foo
          end
          CRYSTAL
        rule.scopes.size.should eq 1
      end
    {% end %}

    it "creates a scope for the def" do
      rule = ScopeRule.new
      ScopeVisitor.new rule, Source.new <<-CRYSTAL
        def method
        end
        CRYSTAL
      rule.scopes.size.should eq 1
    end

    it "creates a scope for the proc" do
      rule = ScopeRule.new
      ScopeVisitor.new rule, Source.new <<-CRYSTAL
        -> {}
        CRYSTAL
      rule.scopes.size.should eq 1
    end

    it "creates a scope for the block" do
      rule = ScopeRule.new
      ScopeVisitor.new rule, Source.new <<-CRYSTAL
        3.times {}
        CRYSTAL
      rule.scopes.size.should eq 2
    end

    context "inner scopes" do
      it "creates scope for block inside def" do
        rule = ScopeRule.new
        ScopeVisitor.new rule, Source.new <<-CRYSTAL
          def method
            3.times {}
          end
          CRYSTAL
        rule.scopes.size.should eq 2
        rule.scopes.last.outer_scope.should_not be_nil
        rule.scopes.first.outer_scope.should eq rule.scopes.last
      end

      it "creates scope for block inside block" do
        rule = ScopeRule.new
        ScopeVisitor.new rule, Source.new <<-CRYSTAL
          3.times do
            2.times {}
          end
          CRYSTAL
        rule.scopes.size.should eq 3
        inner_block = rule.scopes.first
        outer_block = rule.scopes.last
        inner_block.outer_scope.should_not eq outer_block
        outer_block.outer_scope.should be_nil
      end
    end

    context "#visibility" do
      it "is being properly set" do
        rule = ScopeRule.new
        ScopeVisitor.new rule, Source.new <<-CRYSTAL
          private class Foo
          end
          CRYSTAL
        rule.scopes.size.should eq 1
        rule.scopes.first.visibility.should eq Crystal::Visibility::Private
      end

      it "is being inherited from the outer scope(s)" do
        rule = ScopeRule.new
        ScopeVisitor.new rule, Source.new <<-CRYSTAL
          private class Foo
            class Bar
              def baz
              end
            end
          end
          CRYSTAL
        rule.scopes.size.should eq 3
        rule.scopes.each &.visibility.should eq Crystal::Visibility::Private
        rule.scopes.last.node.visibility.should eq Crystal::Visibility::Private
        rule.scopes[0...-1].each &.node.visibility.should eq Crystal::Visibility::Public
      end
    end
  end
end
