require "../../../spec_helper"

module Ameba::Rule::Lint
  describe TopLevelOperatorDefinition do
    subject = TopLevelOperatorDefinition.new

    it "passes for procs" do
      expect_no_issues subject, <<-CRYSTAL
        -> { nil }
        CRYSTAL
    end

    it "passes if an operator method is defined within a class" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def +(other)
          end
        end
        CRYSTAL
    end

    it "passes if an operator method is defined within an enum" do
      expect_no_issues subject, <<-CRYSTAL
        enum Foo
          def +(other)
          end
        end
        CRYSTAL
    end

    it "passes if an operator method is defined within a module" do
      expect_no_issues subject, <<-CRYSTAL
        module Foo
          def +(other)
          end
        end
        CRYSTAL
    end

    it "passes if a top-level operator method has a receiver" do
      expect_no_issues subject, <<-CRYSTAL
        def Foo.+(other)
        end
        CRYSTAL
    end

    it "fails if a + operator method is defined top-level" do
      expect_issue subject, <<-CRYSTAL
        def +(other)
        # ^^^^^^^^^^ error: Top level operator method definitions cannot be called
        end
        CRYSTAL
    end

    it "fails if an index operator method is defined top-level" do
      expect_issue subject, <<-CRYSTAL
        def [](other)
        # ^^^^^^^^^^^ error: Top level operator method definitions cannot be called
        end
        CRYSTAL
    end
  end
end
