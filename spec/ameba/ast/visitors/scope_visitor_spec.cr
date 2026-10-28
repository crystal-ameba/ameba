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

    it "registers unpacked block variables as arguments" do
      rule = ScopeRule.new
      ScopeVisitor.new rule, Source.new <<-CRYSTAL
        [{1, {2, 3}}].each { |(a, (b, *c)), d| a + b + d }
        CRYSTAL
      scope = rule.scopes.first
      scope.arguments.reject(&.anonymous?).map(&.name).sort!.should eq %w[a b c d]
      scope.arguments.find!(&.name.== "a").variable.references.size.should eq 1
      scope.arguments.find!(&.name.== "c").variable.references.should be_empty
    end

    it "registers rescue variables" do
      rule = ScopeRule.new
      ScopeVisitor.new rule, Source.new <<-CRYSTAL
        def foo
          raise "x"
        rescue ex
          puts ex
        end
        CRYSTAL
      scope = rule.scopes.first
      variable = scope.find_variable("ex").should_not be_nil
      variable.assignments.size.should eq 1
      variable.references.size.should eq 1
    end

    it "registers out variables" do
      rule = ScopeRule.new
      ScopeVisitor.new rule, Source.new <<-CRYSTAL
        def foo
          LibFoo.get(out x)
          x
        end
        CRYSTAL
      scope = rule.scopes.first
      variable = scope.find_variable("x").should_not be_nil
      variable.assignments.size.should eq 1
      variable.references.size.should eq 1
    end

    it "registers references taking the variable address" do
      rule = ScopeRule.new
      ScopeVisitor.new rule, Source.new <<-CRYSTAL
        def foo
          a = 1
          ptr = pointerof(a)
          a + ptr.value
        end
        CRYSTAL
      scope = rule.scopes.first
      variable = scope.find_variable("a").should_not be_nil
      variable.references.map(&.address_taken?).should eq [true, false]
    end

    it "assigns rescue variables to the already visible ones" do
      rule = ScopeRule.new
      ScopeVisitor.new rule, Source.new <<-CRYSTAL
        def foo
          ex = nil
          [1].each do
            raise "x"
          rescue ex
          end
          ex
        end
        CRYSTAL
      def_scope = rule.scopes.find!(&.def?)
      block_scope = rule.scopes.find!(&.block?)

      block_scope.variables.should be_empty
      variable = def_scope.find_variable("ex").should_not be_nil
      variable.assignments.size.should eq 2
    end

    it "correctly resets location-less node scope" do
      rule = ScopeRule.new
      ScopeVisitor.new rule, Source.new <<-CRYSTAL
        class Foo       # Scope #1
          def foo?      # Scope #2
            {% begin %} # Scope #3
              # `Crystal::MacroFor` doesn't have location information
              {% for method in @type.ancestors %} # Scope #4
              {% end %}
            {% end %}
          end
        end
        CRYSTAL
      rule.scopes.size.should eq 4
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
        rule.scopes.each(&.visibility.should eq Crystal::Visibility::Private)
        rule.scopes.last.node.visibility.should eq Crystal::Visibility::Private
        rule.scopes[0...-1].each(&.node.visibility.should eq Crystal::Visibility::Public)
      end

      it "is being inherited by all of the inner scopes" do
        rule = ScopeRule.new
        ScopeVisitor.new rule, Source.new <<-CRYSTAL
          private class Foo
            def foo
            end

            def bar
            end

            class Bar
              def baz
              end
            end
          end
          CRYSTAL
        rule.scopes.size.should eq 5
        rule.scopes.each(&.visibility.should eq Crystal::Visibility::Private)
      end

      it "is not being leaked to the following scopes" do
        rule = ScopeRule.new
        ScopeVisitor.new rule, Source.new <<-CRYSTAL
          private alias Foo = Int32

          class Bar
            private getter bar = 1

            class Baz
            end
          end
          CRYSTAL
        rule.scopes.size.should eq 3
        rule.scopes.each(&.visibility.should be_nil)
      end
    end
  end
end
