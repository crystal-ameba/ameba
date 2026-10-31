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

    it "does not report if `self` is used in the presence of an unpacked block argument with the same name" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def foo
            42
          end

          def bar
            [{1, 2}].map { |(foo, _)| self.foo + foo }
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

    it "does not report if `self` is used within the definition of a variable with the same name in class-level blocks" do
      expect_no_issues subject, <<-CRYSTAL
        class Actor
          attribute actor_id : Int32

          after_save do
            actor_id = self.actor_id
            actor_id
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

    it "does not report if `self` is used in the presence of a splat assigned variable with the same name" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def foo
            42
          end

          def bar
            a, *foo = 1, 2, 3
            self.foo + a + foo.size
          end
        end
        CRYSTAL
    end

    it "does not report if `self` is used in the presence of an out variable with the same name" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def foo
            42
          end

          def bar
            LibFoo.get(out foo)
            self.foo + foo
          end
        end
        CRYSTAL
    end

    it "does not report if `self` is used in the presence of a rescue variable with the same name" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def foo
            42
          end

          def bar
            begin
              raise "x"
            rescue foo
              puts self.foo
            end
            foo = 1
          end

          def baz
            begin
              raise "x"
            rescue foo
            end
            self.foo
          end
        end
        CRYSTAL
    end

    it "reports if `self` is used after a rescue variable with the same name declared in a block" do
      expect_issue subject, <<-CRYSTAL
        class Foo
          def foo
            42
          end

          def bar
            [1].each do
              raise "x"
            rescue foo
            end
            self.foo
          # ^^^^ error: Redundant `self` detected
          end
        end
        CRYSTAL
    end

    it "reports if there is redundant `self` used in an instance variable type declaration value" do
      source = expect_issue subject, <<-CRYSTAL
        class Foo
          @x : Int32 = self.bar
                     # ^^^^ error: Redundant `self` detected

          def self.bar
            1
          end
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        class Foo
          @x : Int32 = bar

          def self.bar
            1
          end
        end
        CRYSTAL
    end

    it "does not report if `self` is used in an instance variable type declaration value with a local variable of the same name" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          @x : Int32 = begin
            bar = 2
            self.bar + bar
          end

          def self.bar
            1
          end
        end
        CRYSTAL
    end

    it "does not report if `self` is used in an instance variable initializer with a type body local variable of the same name" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          bar = 2
          puts bar

          @x : Int32 = self.bar

          def self.bar
            1
          end
        end
        CRYSTAL
    end

    it "does not report if `self` is used in an instance variable initializer with a top level variable of the same name" do
      expect_no_issues subject, <<-CRYSTAL
        bar = 2
        puts bar

        class Foo
          @x : Int32 = self.bar

          def self.bar
            1
          end
        end
        CRYSTAL
    end

    it "does not report if `self` is used in a type body with a top level variable of the same name" do
      expect_no_issues subject, <<-CRYSTAL
        bar = 2
        puts bar

        class Foo
          def self.bar
            1
          end

          puts self.bar
        end
        CRYSTAL
    end

    it "reports if `self` is used in a method with a top level variable of the same name" do
      expect_issue subject, <<-CRYSTAL
        bar = 2
        puts bar

        class Foo
          def bar
            1
          end

          def baz
            self.bar
          # ^^^^ error: Redundant `self` detected
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

    context "within blocks" do
      it "reports and corrects redundant `self` within a block" do
        source = expect_issue subject, <<-CRYSTAL
          class Foo
            def foo
              42
            end

            def bar
              build do
                self.foo
              # ^^^^ error: Redundant `self` detected
                [1].each { self.foo }
                         # ^^^^ error: Redundant `self` detected
              end
            end
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          class Foo
            def foo
              42
            end

            def bar
              build do
                foo
                [1].each { foo }
              end
            end
          end
          CRYSTAL
      end

      it "reports and corrects redundant `self` within a proc literal" do
        source = expect_issue subject, <<-CRYSTAL
          class Foo
            def foo
              42
            end

            def bar
              -> { self.foo }
                 # ^^^^ error: Redundant `self` detected
            end
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          class Foo
            def foo
              42
            end

            def bar
              -> { foo }
            end
          end
          CRYSTAL
      end

      it "reports and corrects redundant `self` within a method defined in a block" do
        source = expect_issue subject, <<-CRYSTAL
          build do
            class Foo
              def foo
                42
              end

              def bar
                self.foo
              # ^^^^ error: Redundant `self` detected
              end
            end
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          build do
            class Foo
              def foo
                42
              end

              def bar
                foo
              end
            end
          end
          CRYSTAL
      end
    end

    context "properties" do
      describe "#autocorrect_in_blocks" do
        it "reports without correcting redundant `self` within a block if disabled" do
          rule = subject.class.new
          rule.autocorrect_in_blocks = false

          source = expect_issue rule, <<-CRYSTAL
            class Foo
              def foo
                42
              end

              def bar
                build do
                  self.foo
                # ^^^^ error: Redundant `self` detected
                  [1].each { self.foo }
                           # ^^^^ error: Redundant `self` detected
                end
              end
            end
            CRYSTAL

          expect_no_corrections source
        end

        it "still corrects redundant `self` outside of blocks if disabled" do
          rule = subject.class.new
          rule.autocorrect_in_blocks = false

          source = expect_issue rule, <<-CRYSTAL
            class Foo
              def foo
                42
              end

              def bar
                self.foo
              # ^^^^ error: Redundant `self` detected
              end
            end
            CRYSTAL

          expect_correction source, <<-CRYSTAL
            class Foo
              def foo
                42
              end

              def bar
                foo
              end
            end
            CRYSTAL
        end
      end
    end
  end
end
