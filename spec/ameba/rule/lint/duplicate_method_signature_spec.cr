require "../../../spec_helper"

module Ameba::Rule::Lint
  describe DuplicateMethodSignature do
    subject = DuplicateMethodSignature.new

    it "passes if there are no duplicate methods" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def foo; end
          def foo(&); end
          def foo?; end
          def foo!; end
          def foo(
            bar : Bar,
          )
          end
          def foo(
            baz : Baz,
          )
          end
        end
        CRYSTAL
    end

    it "passes if there are duplicate methods with `previous_def`" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def foo
            42
          end

          def foo
            previous_def if rand >= 0.42
            24
          end
        end
        CRYSTAL
    end

    it "reports if there are duplicate methods without `previous_def`" do
      expect_issue subject, <<-CRYSTAL
        class Foo
          def foo
            42
          end

          def foo
        # ^^^^^^^ error: Duplicate method signature detected
            previous_definition if rand >= 0.42
            24
          end
        end
        CRYSTAL
    end

    it "reports if there are multiple duplicate methods" do
      expect_issue subject, <<-CRYSTAL
        class Foo
          def foo; end
          def bar; end
          def foo; end
        # ^^^^^^^^^^^^ error: Duplicate method signature detected
          def foo; end
        # ^^^^^^^^^^^^ error: Duplicate method signature detected
        end
        CRYSTAL
    end

    it "reports if there are duplicate methods (with block)" do
      expect_issue subject, <<-CRYSTAL
        class Foo
          def foo(&); end
          def bar(&); end
          def foo(&); end
        # ^^^^^^^^^^^^^^^ error: Duplicate method signature detected
        end
        CRYSTAL
    end

    it "reports if there are duplicate methods (with visibility modifier)" do
      expect_issue subject, <<-CRYSTAL
        class Foo
          def foo; end
          private def foo; end
                # ^^^^^^^^^^^^ error: Duplicate method signature detected
          protected def foo; end
                  # ^^^^^^^^^^^^ error: Duplicate method signature detected
        end
        CRYSTAL
    end

    it "reports if there are duplicate methods (with arguments)" do
      expect_issue subject, <<-CRYSTAL
        class Foo
          def foo(a, b, c = 3, &); end
          def foo(a, b, c = 3); end
          def foo(a, b, c = 3); end
        # ^^^^^^^^^^^^^^^^^^^^^^^^^ error: Duplicate method signature detected
        end
        CRYSTAL
    end

    it "reports if there are duplicate methods with different bodies" do
      expect_issue subject, <<-CRYSTAL
        class Foo
          def foo(a, b, c = 3)
            puts :foo
          end

          def foo(a, b, c = 3)
        # ^^^^^^^^^^^^^^^^^^^^ error: Duplicate method signature detected
            puts :bar
          end
        end
        CRYSTAL
    end
  end
end
