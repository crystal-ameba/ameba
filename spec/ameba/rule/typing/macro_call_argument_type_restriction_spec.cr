require "../../../spec_helper"

module Ameba::Rule::Typing
  describe MacroCallArgumentTypeRestriction do
    subject = MacroCallArgumentTypeRestriction.new

    it "passes if macro call args have type restrictions" do
      expect_no_issues subject, <<-CRYSTAL
        class Greeter
          getter name : String?
          class_getter age : Int32 = 0
          setter tasks : Array(String) = [] of String
          class_setter queue : Array(Int32)?
          property task_mutex : Mutex = Mutex.new
          class_property asdf : String
        end

        record Task,
          cmd : String,
          args : Array(String) = %w[]
        CRYSTAL
    end

    it "fails if a macro call arg doesn't have a type restriction" do
      expect_issue subject, <<-CRYSTAL
        class Greeter
          getter name
               # ^^^^ error: Argument should have a type restriction
          getter :age
               # ^^^^ error: Argument should have a type restriction
          getter "height"
               # ^^^^^^^^ error: Argument should have a type restriction
        end
        CRYSTAL
    end

    it "passes if a record call arg with a default value doesn't have a type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        record Task,
          cmd : String,
          args = %[]
        CRYSTAL
    end

    context "properties" do
      context "#default_value" do
        rule = MacroCallArgumentTypeRestriction.new
        rule.default_value = true

        it "fails if a macro call arg with a default value doesn't have a type restriction" do
          expect_issue rule, <<-CRYSTAL
            class Greeter
              getter name = "Kenobi"
                   # ^^^^ error: Argument should have a type restriction
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
