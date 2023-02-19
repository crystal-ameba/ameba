require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = UnusedBlockArgument.new

  describe UnusedBlockArgument do
    it "doesn't report if it is an instance var argument" do
      expect_no_issues subject, <<-CRYSTAL
        class A
          def initialize(&@callback)
          end
        end
        CRYSTAL
    end

    it "doesn't report if anonymous" do
      expect_no_issues subject, <<-CRYSTAL
        def method(a, b, c, &)
        end
        CRYSTAL
    end

    it "doesn't report if argument name starts with a `_`" do
      expect_no_issues subject, <<-CRYSTAL
        def method(a, b, c, &_block)
        end
        CRYSTAL
    end

    it "doesn't report if it is a block and used" do
      expect_no_issues subject, <<-CRYSTAL
        def method(a, b, c, &block)
          block.call
        end
        CRYSTAL
    end

    it "reports if block arg is not used" do
      source = expect_issue subject, <<-CRYSTAL
        def method(a, b, c, &block)
                           # ^^^^^ error: Unused block argument `block`. [...]
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def method(a, b, c, &_block)
        end
        CRYSTAL
    end

    it "reports if unused and there is yield" do
      source = expect_issue subject, <<-CRYSTAL
        def method(a, b, c, &block)
                           # ^^^^^ error: Use `&` as an argument name to indicate that it won't be referenced.
          3.times do |i|
            i.try do
              yield i
            end
          end
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def method(a, b, c, &)
          3.times do |i|
            i.try do
              yield i
            end
          end
        end
        CRYSTAL
    end

    it "doesn't report if anonymous and there is yield" do
      expect_no_issues subject, <<-CRYSTAL
        def method(a, b, c, &)
          yield 1
        end
        CRYSTAL
    end

    it "doesn't report if variable is referenced implicitly" do
      expect_no_issues subject, <<-CRYSTAL
        class Bar < Foo
          def method(a, b, c, &block)
            super
          end
        end
        CRYSTAL
    end

    it "doesn't report if used in abstract def" do
      expect_no_issues subject, <<-CRYSTAL
        abstract def debug(id : String, &on_message: Callback)
        abstract def info(&on_message: Callback)
        CRYSTAL
    end

    context "super" do
      it "reports if variable is not referenced implicitly by super" do
        source = expect_issue subject, <<-CRYSTAL
          class Bar < Foo
            def method(a, b, c, &block)
                               # ^^^^^ error: Unused block argument `block`. [...]
              super a, b, c
            end
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          class Bar < Foo
            def method(a, b, c, &_block)
              super a, b, c
            end
          end
          CRYSTAL
      end
    end

    context "macro" do
      it "doesn't report if it is a used macro block argument" do
        expect_no_issues subject, <<-CRYSTAL
          macro my_macro(&block)
            {% block %}
          end
          CRYSTAL
      end
    end
  end
end
