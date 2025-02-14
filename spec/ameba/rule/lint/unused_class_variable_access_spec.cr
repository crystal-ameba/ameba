require "../../../spec_helper"

module Ameba::Rule::Lint
  describe UnusedClassVariableAccess do
    subject = UnusedClassVariableAccess.new

    it "passes if class variables are used for assignment" do
      expect_no_issues subject, <<-CRYSTAL
        class MyClass
          a = @@ivar
          B = @@ivar
        end
        CRYSTAL
    end

    it "passes if an class variable is used as a target in multi-assignment" do
      expect_no_issues subject, <<-CRYSTAL
        class MyClass
          @@a, @@b = 1, 2
        end
        CRYSTAL
    end

    it "fails if class variables are unused in void context of class" do
      expect_issue subject, <<-CRYSTAL
        class Actor
          @@name : String = "George"

          @@name
        # ^^^^^^ error: Value from class variable access is unused
        end
        CRYSTAL
    end

    it "fails if class variables are unused in void context of method" do
      expect_issue subject, <<-'CRYSTAL'
        def hello : String
          @@name
        # ^^^^^^ error: Value from class variable access is unused

          "Hello, #{@@name}!"
        end
        CRYSTAL
    end
  end
end
