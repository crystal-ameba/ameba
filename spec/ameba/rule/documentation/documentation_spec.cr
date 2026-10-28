require "../../../spec_helper"

module Ameba::Rule::Documentation
  describe Documentation do
    subject = Documentation.new
    subject.ignore_classes = false
    subject.ignore_modules = false
    subject.ignore_enums = false
    subject.ignore_defs = false
    subject.ignore_macros = false

    it "passes for undocumented private types" do
      expect_no_issues subject, <<-CRYSTAL
        private class Foo
          def foo
          end
        end

        private module Bar
          def bar
          end
        end

        private enum Baz
        end

        private def bat
        end

        private macro bag
        end
        CRYSTAL
    end

    it "passes for documented public types" do
      expect_no_issues subject, <<-CRYSTAL
        # Foo
        class Foo
          # foo
          def foo
          end
        end

        # Bar
        module Bar
          # bar
          def bar
          end
        end

        # Baz
        enum Baz
        end

        # bat
        def bat
        end

        # bag
        macro bag
        end
        CRYSTAL
    end

    it "passes for undocumented public types within `:nodoc:` namespaces" do
      expect_no_issues subject, <<-CRYSTAL
        # :nodoc:
        module Foo
          class Bar
          end

          module Baz
            macro bat
            end
          end
        end
        CRYSTAL
    end

    it "fails for undocumented public types declared with absolute path within `:nodoc:` namespaces" do
      expect_issue subject, <<-CRYSTAL
        # :nodoc:
        module Foo
          class ::Bar
        # ^^^^^^^^^^^ error: Missing documentation
            class Baz
          # ^^^^^^^^^ error: Missing documentation
            end
          end
        end
        CRYSTAL
    end

    it "passes for undocumented public defs within private types" do
      expect_no_issues subject, <<-CRYSTAL
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
    end

    it "fails for undocumented public types declared with absolute path within private namespaces" do
      expect_issue subject, <<-CRYSTAL
        private module Foo
          class ::Bar
        # ^^^^^^^^^^^ error: Missing documentation
            def baz
          # ^^^^^^^ error: Missing documentation
            end
          end
        end
        CRYSTAL
    end

    it "passes for undocumented types within `:nodoc:` types declared with absolute path" do
      expect_issue subject, <<-CRYSTAL
        module Foo
        # ^^^^^^^^ error: Missing documentation
          # :nodoc:
          class ::Bar
            enum Baz
              A
            end
          end
        end
        CRYSTAL
    end

    it "fails if there is an undocumented public type" do
      expect_issue subject, <<-CRYSTAL
        class Foo
        # ^^^^^^^ error: Missing documentation
        end

        module Bar
        # ^^^^^^^^ error: Missing documentation
        end

        enum Baz
        # ^^^^^^ error: Missing documentation
        end

        def bat
        # ^^^^^ error: Missing documentation
        end

        macro bag
        # ^^^^^^^ error: Missing documentation
        end
        CRYSTAL
    end

    context "properties" do
      describe "#ignore_classes" do
        it "lets the rule to ignore method definitions if true" do
          rule = subject.class.new
          rule.ignore_classes = true

          expect_no_issues rule, <<-CRYSTAL
            class Foo
            end
            CRYSTAL
        end
      end

      describe "#ignore_modules" do
        it "lets the rule to ignore method definitions if true" do
          rule = subject.class.new
          rule.ignore_modules = true

          expect_no_issues rule, <<-CRYSTAL
            module Bar
            end
            CRYSTAL
        end
      end

      describe "#ignore_enums" do
        it "lets the rule to ignore method definitions if true" do
          rule = subject.class.new
          rule.ignore_enums = true

          expect_no_issues rule, <<-CRYSTAL
            enum Baz
            end
            CRYSTAL
        end
      end

      describe "#ignore_defs" do
        it "lets the rule to ignore method definitions if true" do
          rule = subject.class.new
          rule.ignore_defs = true

          expect_no_issues rule, <<-CRYSTAL
            def bat
            end
            CRYSTAL
        end
      end

      describe "#ignore_macros" do
        it "lets the rule to ignore macros if true" do
          rule = subject.class.new
          rule.ignore_macros = true

          expect_no_issues rule, <<-CRYSTAL
            macro bag
            end
            CRYSTAL
        end
      end

      describe "#require_example" do
        rule = subject.class.new
        rule.require_example = true

        it "fails if there is a documented public type without example" do
          expect_issue rule, <<-CRYSTAL
            # Foo documentation
            class Foo
            # ^^^^^^^ error: Missing documentation example
            end
            CRYSTAL
        end

        it "passes if there is a `:nodoc:` public type without example" do
          expect_no_issues rule, <<-CRYSTAL
            # :nodoc:
            class Foo
            end
            CRYSTAL
        end

        it "passes if there is a documented public type with example" do
          expect_no_issues rule, <<-CRYSTAL
            # Foo documentation
            #
            # ```
            # foo = Foo.new
            # foo.bar # => :baz
            # ```
            class Foo
            end
            CRYSTAL
        end

        it "passes if there is a documented public type with crystal-tagged example" do
          expect_no_issues rule, <<-CRYSTAL
            # Foo documentation
            #
            # ```crystal
            # foo = Foo.new
            # ```
            class Foo
            end
            CRYSTAL
        end

        it "fails if there is a documented public type with non-crystal example" do
          expect_issue rule, <<-CRYSTAL
            # Foo documentation
            #
            # ```text
            # foo
            # ```
            class Foo
            # ^^^^^^^ error: Missing documentation example
            end
            CRYSTAL
        end
      end
    end
  end
end
