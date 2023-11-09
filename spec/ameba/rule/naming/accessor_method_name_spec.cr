require "../../../spec_helper"

module Ameba::Rule::Naming
  subject = AccessorMethodName.new

  describe AccessorMethodName do
    it "passes if accessor method name is correct" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def self.instance
          end

          def self.instance=(value)
          end

          def user
          end

          def user=(user)
          end
        end
        CRYSTAL
    end

    it "passes if accessor method is defined in top-level scope" do
      expect_no_issues subject, <<-CRYSTAL
        def get_user
        end

        def set_user(user)
        end
        CRYSTAL
    end

    it "fails if accessor method is defined with receiver in top-level scope" do
      expect_issue subject, <<-CRYSTAL
        def Foo.get_user
              # ^^^^^^^^ error: Favour method name 'user' over 'get_user'
        end

        def Foo.set_user(user)
              # ^^^^^^^^ error: Favour method name 'user=' over 'set_user'
        end
        CRYSTAL
    end

    it "fails if accessor method name is wrong" do
      expect_issue subject, <<-CRYSTAL
        class Foo
          def self.get_instance
                 # ^^^^^^^^^^^^ error: Favour method name 'instance' over 'get_instance'
          end

          def self.set_instance(value)
                 # ^^^^^^^^^^^^ error: Favour method name 'instance=' over 'set_instance'
          end

          def get_user
            # ^^^^^^^^ error: Favour method name 'user' over 'get_user'
          end

          def set_user(user)
            # ^^^^^^^^ error: Favour method name 'user=' over 'set_user'
          end
        end
        CRYSTAL
    end

    it "ignores if alternative name isn't valid syntax" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def get_404
          end

          def set_404(value)
          end
        end
        CRYSTAL
    end

    it "ignores if the method has unexpected arity" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          def get_user(type)
          end

          def set_user(user, type)
          end
        end
        CRYSTAL
    end
  end
end
