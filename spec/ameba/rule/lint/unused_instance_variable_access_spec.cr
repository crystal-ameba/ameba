require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = UnusedInstanceVariableAccess.new

  describe UnusedInstanceVariableAccess do
    it "passes if instance variables are used" do
      expect_no_issues subject, <<-CRYSTAL
        class MyClass
          a = @ivar
          B = @ivar
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

    it "fails if instance variables are unused" do
      expect_issue subject, <<-CRYSTAL
        class Actor
          @name : String = "George"

          @name
        # ^^^^^ error: Value from instance variable access is unused

          puts @name

          def hello : String
            @name
          # ^^^^^ error: Value from instance variable access is unused

            "Hello, \#{@name}!"
          end
        end
        CRYSTAL
    end
  end
end
