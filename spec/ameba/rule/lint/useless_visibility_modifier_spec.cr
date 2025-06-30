require "../../../spec_helper"

module Ameba::Rule::Lint
  describe UselessVisibilityModifier do
    subject = UselessVisibilityModifier.new

    it "passes for procs" do
      expect_no_issues subject, <<-CRYSTAL
        -> { nil }
        CRYSTAL
    end

    it "passes for definitions with a receiver" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
        end

        protected def Foo.foo
        end
        CRYSTAL
    end

    it "passes for calls" do
      expect_no_issues subject, <<-CRYSTAL
        record Foo do
          protected def foo
          end
        end
        CRYSTAL
    end

    it "passes if a `protected` method visibility modifier is not used" do
      expect_no_issues subject, <<-CRYSTAL
        private def foo; end
        def bar; end
        CRYSTAL
    end

    {% for keyword in %w[enum class module].map(&.id) %}
      it "passes if a `protected` method visibility modifier is used within a {{ keyword }}" do
        expect_no_issues subject, <<-CRYSTAL
          {{ keyword }} Foo
            protected def foo
            end
          end
          CRYSTAL
      end
    {% end %}
  end
end
