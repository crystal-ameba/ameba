require "../../../spec_helper"

module Ameba::Rule::Lint
  describe UnusedInstanceVariableAccess do
    subject = UnusedInstanceVariableAccess.new

    it "passes if instance variables are used for assignment" do
      expect_no_issues subject, <<-CRYSTAL
        class MyClass
          a = @ivar
          B = @ivar
        end
        CRYSTAL
    end

    it "passes if @type is unused within a macro expression" do
      expect_no_issues subject, <<-CRYSTAL
        def foo
          {% @type %}
          :bar
        end
        CRYSTAL
    end

    it "passes if an instance variable is used as a target in multi-assignment" do
      expect_no_issues subject, <<-CRYSTAL
        class MyClass
          @a, @b = 1, 2
        end
        CRYSTAL
    end

    it "fails if instance variables are unused in void context of class" do
      expect_issue subject, <<-CRYSTAL
        class Actor
          @name : String = "George"

          @name
        # ^^^^^ error: Value from instance variable access is unused
        end
        CRYSTAL
    end

    it "fails if instance variables are unused in void context of method" do
      expect_issue subject, <<-CRYSTAL
        def hello : String
          @name
        # ^^^^^ error: Value from instance variable access is unused

          "Hello, \#{@name}!"
        end
        CRYSTAL
    end
  end
end
