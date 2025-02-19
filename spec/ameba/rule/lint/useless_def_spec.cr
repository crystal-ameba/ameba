require "../../../spec_helper"

module Ameba::Rule::Lint
  describe UselessDef do
    subject = UselessDef.new

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
        # ^^^^^^^^^^ error: Useless method definition
        end
        CRYSTAL
    end

    it "fails if an index operator method is defined top-level" do
      expect_issue subject, <<-CRYSTAL
        def [](other)
        # ^^^^^^^^^^^ error: Useless method definition
        end
        CRYSTAL
    end
  end
end
