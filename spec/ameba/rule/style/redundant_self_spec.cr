require "../../../spec_helper"

module Ameba::Rule::Style
  describe RedundantSelf do
    subject = RedundantSelf.new

    it "does not report solitary `self` reference" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def bar
            self
          end
        end
        CRYSTAL
    end

    it "does not report calls without a receiver" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def foo; end

          def foo!
            foo || 42
          end
        end
        CRYSTAL
    end

    it "does not report if `self` is used in a method call with a reserved keyword" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def foo
            if self.responds_to?(:with)
              self.with { 42 }
            end
            self.is_a?(Foo) ? self.class : self.as?(Foo)
          end
        end
        CRYSTAL
    end

    it "does not report if `self` is used in the presence of a method argument with the same name" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def foo; end

          def bar(foo)
            foo || self.foo
          end
        end
        CRYSTAL
    end

    it "does not report if `self` is used in the presence of a block argument with the same name" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def foo
            42
          end

          def bar
            [1, 11, 111].map { |foo| self.foo + foo }
          end
        end
        CRYSTAL
    end

    it "does not report if `self` is used in the presence of a block argument with the same name (inside block)" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def foo
            42
          end

          def bar
            foo : Int32?

            1.try do |x|
              2.try do |y|
                3.try do |z|
                  self.foo + foo
                end
              end
            end
          end
        end
        CRYSTAL
    end

    it "does not report if `self` is used in the presence of a method argument with the same name inherited from the parent scope" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def foo
            42
          end

          def bar(foo)
            [1, 11, 111].map { |n| self.foo + n }
          end
        end
        CRYSTAL
    end

    it "does not report if `self` is used in the presence of a proc argument with the same name" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def foo
            42
          end

          def bar
            -> (foo : Int32) { self.foo + foo }
          end
        end
        CRYSTAL
    end

    it "does not report if `self` is used within the definition of a variable with the same name" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def foo; end

          def foo!
            foo = self.foo
            foo
          end
        end
        CRYSTAL
    end

    it "does not report if `self` is used in the presence of a variable with the same name" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def foo; end

          def foo!
            foo = 42
            bar = self.foo
            bar
          end
        end
        CRYSTAL
    end

    it "does not report if `self` is used in the presence of a type declaration variable with the same name" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def foo; end

          def foo!
            foo : Int32 = 42
            bar = self.foo
            bar
          end
        end
        CRYSTAL
    end

    it "does not report if `self` is used in the presence of a type declaration variable with the same name (2)" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def foo; end

          def foo!
            foo : Int32?
            bar = self.foo
            bar
          end
        end
        CRYSTAL
    end

    it "does not report if `self` is used with a setter" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def foo=(value); end

          def foo!
            self.foo = 42
          end
        end
        CRYSTAL
    end

    it "does not report if `self` is used with an operator assign" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def foo=(value); end

          def foo!
            self.foo ||= 42
            self.foo &&= 42
            self.foo += 42
            self.foo -= 42
            self.foo *= 42
            self.foo /= 42
            self.foo %= 42
          end
        end
        CRYSTAL
    end

    it "does not report if `self` is used with an operator" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def +(value); end
          def %(value); end
          def <<(value); end

          def foo
            self + "foo"
            self % "foo"
            self << "foo"
          end

          self | String
        end
        CRYSTAL
    end

    it "does not report if `self` is used with a square bracket operator" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def []?(i); end
          def [](i); end
          def []=(i, value); end

          def foo?
            self[0]?
          end

          def foo
            self[0]
          end

          def foo!
            self[0] = 42
          end
        end
        CRYSTAL
    end

    it "reports if `self` is used in the presence of a type declaration with the same name in outer scope" do
      expect_issue subject, <<-CRYSTAL
        class Foo
          foo : Int32?

          def foo; end

          def foo!
            bar = self.foo
                # ^^^^ error: Redundant `self` detected
            bar
          end
        end
        CRYSTAL
    end

    it "reports if there is redundant `self` used in a method body" do
      source = expect_issue subject, <<-CRYSTAL
        class Foo
          def foo(&); end

          def foo!
            self.foo { nil } || 42
          # ^^^^ error: Redundant `self` detected
          end
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        class Foo
          def foo(&); end

          def foo!
            foo { nil } || 42
          end
        end
        CRYSTAL
    end

    it "correctly replaces multiline calls" do
      source = expect_issue subject, <<-CRYSTAL
        class Foo
          property bar : String

          def foo
            self
          # ^^^^ error: Redundant `self` detected
              .bar
              .chars.map do |char|
                char.upcase
              end
              .each { |char| raise "Boom!" if char.empty? }
          end
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        class Foo
          property bar : String

          def foo
            bar
              .chars.map do |char|
                char.upcase
              end
              .each { |char| raise "Boom!" if char.empty? }
          end
        end
        CRYSTAL
    end

    it "reports if there is redundant `self` used in a method arguments' default values" do
      source = expect_issue subject, <<-CRYSTAL
        class Foo
          def foo
            42
          end

          def foo!(bar = self.foo, baz = false)
                       # ^^^^ error: Redundant `self` detected
          end
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        class Foo
          def foo
            42
          end

          def foo!(bar = foo, baz = false)
          end
        end
        CRYSTAL
    end

    it "reports if there is redundant `self` used in a string interpolation" do
      source = expect_issue subject, <<-'CRYSTAL'
        class Foo
          def foo; end

          def foo!
            "#{self.foo || 42}"
             # ^^^^ error: Redundant `self` detected
          end
        end
        CRYSTAL

      expect_correction source, <<-'CRYSTAL'
        class Foo
          def foo; end

          def foo!
            "#{foo || 42}"
          end
        end
        CRYSTAL
    end

    {% for keyword in %w[class module].map(&.id) %}
      it "reports if there is redundant `self` within {{ keyword }} definition" do
        source = expect_issue subject, <<-CRYSTAL
          {{ keyword }} Foo
            def self.foo; end

            self.foo
          # ^^^^ error: Redundant `self` detected
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          {{ keyword }} Foo
            def self.foo; end

            foo
          end
          CRYSTAL
      end
    {% end %}
  end
end
