require "../../../spec_helper"

module Ameba::Rule::Lint
  describe ReadInstanceVar do
    subject = ReadInstanceVar.new

    it "passes if an instance var is read from a var of the same type of the current class" do
      expect_no_issues subject, <<-CRYSTAL
        class MyClass
          def test(other : MyClass)
            @instance_var <=> other.@instance_var
          end
        end
        CRYSTAL
    end

    it "passes if an instance var is read from a var typed as `self`" do
      expect_no_issues subject, <<-CRYSTAL
        class MyClass
          def test(other : self)
            @instance_var <=> other.@instance_var
          end
        end
        CRYSTAL
    end

    it "fails if an instance var is read from an untyped var in a class" do
      expect_issue subject, <<-CRYSTAL
        class MyClass
          def test(other)
            @instance_var <=> other.@instance_var
                            # ^^^^^^^^^^^^^^^^^^^ error: Reading instance variables externally is not allowed.
          end
        end
        CRYSTAL
    end

    it "fails if an instance var is read externally top-level" do
      expect_issue subject, <<-CRYSTAL
        a = MyClass.new
        a.@instance_var
        # ^^^^^^^^^^^^^ error: Reading instance variables externally is not allowed.
        CRYSTAL
    end

    it "fails reading an instance var externally from a different ivar" do
      expect_issue subject, <<-CRYSTAL
        class MyClass
          @a.@instance_var
        # ^^^^^^^^^^^^^^^^ error: Reading instance variables externally is not allowed.

          def method
            OtherClass.new(@a.@instance_var)
                         # ^^^^^^^^^^^^^^^^ error: Reading instance variables externally is not allowed.
          end
        end
        CRYSTAL
    end
  end
end
