require "../../../spec_helper"

module Ameba::Rule::Typing
  describe MacroCallArgumentTypeRestriction do
    subject = MacroCallArgumentTypeRestriction.new

    it "passes if macro call args have type restrictions" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          getter foo : Int32?
          setter bar : Array(Int32)?
          property baz : Bool?
        end

        record Task,
          cmd : String,
          args : Array(String)
        CRYSTAL
    end

    it "passes if macro call args have default values" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          getter foo = 0
          setter bar = [] of Int32
          property baz = true
        end

        record Task,
          cmd = "",
          args = %w[]
        CRYSTAL
    end

    it "fails if a macro call arg doesn't have a type restriction" do
      expect_issue subject, <<-CRYSTAL
        class Foo
          getter foo
               # ^^^ error: Argument should have a type restriction
          getter :bar
               # ^^^^ error: Argument should have a type restriction
          getter "baz"
               # ^^^^^ error: Argument should have a type restriction
        end
        CRYSTAL
    end

    context "properties" do
      context "#default_value" do
        rule = MacroCallArgumentTypeRestriction.new
        rule.default_value = true

        it "fails if a macro call arg with a default value doesn't have a type restriction" do
          expect_issue rule, <<-CRYSTAL
            class Foo
              getter foo = "bar"
                   # ^^^ error: Argument should have a type restriction
            end
            CRYSTAL
        end

        it "fails if a record call arg with default value doesn't have a type restriction" do
          expect_issue rule, <<-CRYSTAL
            record Task,
              cmd : String,
              args = %[]
            # ^^^^ error: Argument should have a type restriction
            CRYSTAL
        end
      end
    end
  end
end
