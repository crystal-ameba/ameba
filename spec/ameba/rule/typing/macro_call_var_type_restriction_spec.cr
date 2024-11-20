require "../../../spec_helper"

module Ameba::Rule::Typing
  subject = MacroCallVarTypeRestriction.new

  it "passes if macro call args have type restrictions" do
    expect_no_issues subject, <<-CRYSTAL
      class Greeter
        getter name : String?
        class_getter age : Int32 = 0
        setter tasks : Array(String) = [] of String
        class_setter queue : Array(Int32)?
        property task_mutex : Mutex = Mutex.new
        class_property asdf : String

        record Task,
          var1 : String,
          var2 : String = "asdf"
      end
      CRYSTAL
  end

  it "fails if a macro call arg doesn't have a type restriction" do
    expect_issue subject, <<-CRYSTAL
      class Greeter
        getter name
             # ^^^^ error: Variable arguments to `getter` require a type restriction
      end
      CRYSTAL
  end

  it "fails if a record call arg doesn't have a type restriction" do
    expect_issue subject, <<-CRYSTAL
      class Greeter
        record Task,
          var1 : String,
          var2 = "asdf"
        # ^^^^ error: Variable arguments to `record` require a type restriction
      end
      CRYSTAL
  end
end
