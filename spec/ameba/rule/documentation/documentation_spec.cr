require "../../../spec_helper"

module Ameba::Rule::Documentation
  subject = Documentation.new
    .tap(&.ignore_classes = false)
    .tap(&.ignore_modules = false)
    .tap(&.ignore_enums = false)
    .tap(&.ignore_defs = false)
    .tap(&.ignore_macros = false)

  describe Documentation do
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

    it "fails if there is an undocumented public type" do
      expect_issue subject, <<-CRYSTAL
        class Foo
      # ^^^^^^^^^ error: Missing documentation
        end

        module Bar
      # ^^^^^^^^^^ error: Missing documentation
        end

        enum Baz
      # ^^^^^^^^ error: Missing documentation
        end

        def bat
      # ^^^^^^^ error: Missing documentation
        end

        macro bag
      # ^^^^^^^^^ error: Missing documentation
        end
      CRYSTAL
    end

    context "properties" do
      describe "#ignore_classes" do
        it "lets the rule to ignore method definitions if true" do
          rule = Documentation.new
          rule.ignore_classes = true

          expect_no_issues rule, <<-CRYSTAL
            class Foo
            end
            CRYSTAL
        end
      end

      describe "#ignore_modules" do
        it "lets the rule to ignore method definitions if true" do
          rule = Documentation.new
          rule.ignore_modules = true

          expect_no_issues rule, <<-CRYSTAL
            module Bar
            end
            CRYSTAL
        end
      end

      describe "#ignore_enums" do
        it "lets the rule to ignore method definitions if true" do
          rule = Documentation.new
          rule.ignore_enums = true

          expect_no_issues rule, <<-CRYSTAL
            enum Baz
            end
            CRYSTAL
        end
      end

      describe "#ignore_defs" do
        it "lets the rule to ignore method definitions if true" do
          rule = Documentation.new
          rule.ignore_defs = true

          expect_no_issues rule, <<-CRYSTAL
            def bat
            end
            CRYSTAL
        end
      end

      describe "#ignore_macros" do
        it "lets the rule to ignore macros if true" do
          rule = Documentation.new
          rule.ignore_macros = true

          expect_no_issues rule, <<-CRYSTAL
            macro bag
            end
            CRYSTAL
        end
      end
    end
  end
end
