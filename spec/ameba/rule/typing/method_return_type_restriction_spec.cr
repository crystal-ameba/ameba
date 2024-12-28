require "../../../spec_helper"

module Ameba::Rule::Typing
  subject = MethodReturnTypeRestriction.new

  it "passes if a method has a return type" do
    expect_no_issues subject, <<-CRYSTAL
      def hello : String
        "hello world"
      end

      private def hello : String
        "hello world"
      end

      protected def hello : String
        "hello world"
      end
      CRYSTAL
  end

  it "passes if an undocumented method doesn't have a return type" do
    expect_no_issues subject, <<-CRYSTAL
      def hello
        "hello world"
      end

      private def hello
        "hello world"
      end

      protected def hello : String
        "hello world"
      end

      # :nodoc:
      def hello
        "hello world"
      end
      CRYSTAL
  end

  it "fails if a documented method doesn't have a return type" do
    expect_issue subject, <<-CRYSTAL
      # This method is documented
      def hello
        # ^^^^^ error: Methods should have a return type restriction
        "hello world"
      end
      CRYSTAL
  end

  context "properties" do
    context "#private_methods" do
      rule = MethodReturnTypeRestriction.new
      rule.private_methods = true

      it "passes if a method has a return type" do
        expect_no_issues rule, <<-CRYSTAL
          def hello : String
            "hello world"
          end

          # This method is documented
          def hello : String
            "hello world"
          end

          private def hello : String
            "hello world"
          end

          protected def hello : String
            "hello world"
          end

          # :nodoc:
          def hello : String
            "hello world"
          end
          CRYSTAL
      end

      it "passes if an undocumented public or protected method doesn't have a return type" do
        expect_no_issues rule, <<-CRYSTAL
          def hello
            "hello world"
          end

          protected def hello
            "hello world"
          end

          # :nodoc:
          def hello
            "hello world"
          end
          CRYSTAL
      end

      it "fails if a documented public or private method doesn't have a return type" do
        expect_issue rule, <<-CRYSTAL
          # This method is documented
          def hello
            # ^^^^^ error: Methods should have a return type restriction
            "hello world"
          end

          # This method is also documented
          private def hello
                    # ^^^^^ error: Methods should have a return type restriction
            "hello world"
          end
          CRYSTAL
      end
    end

    context "#protected_methods" do
      rule = MethodReturnTypeRestriction.new
      rule.protected_methods = true

      it "passes if a method has a return type" do
        expect_no_issues rule, <<-CRYSTAL
          protected def hello : String
            "hello world"
          end
          CRYSTAL
      end

      it "passes if an undocumented public or private method doesn't have a return type" do
        expect_no_issues rule, <<-CRYSTAL
          def hello
            "hello world"
          end

          private def hello
            "hello world"
          end

          # :nodoc:
          def hello
            "hello world"
          end
          CRYSTAL
      end

      it "fails if a documented public or protected method doesn't have a return type" do
        expect_issue rule, <<-CRYSTAL
          # This method is documented
          def hello
            # ^^^^^ error: Methods should have a return type restriction
            "hello world"
          end

          # This method is also documented
          protected def hello
                      # ^^^^^ error: Methods should have a return type restriction
            "hello world"
          end
          CRYSTAL
      end
    end

    context "#undocumented" do
      rule = MethodReturnTypeRestriction.new
      rule.undocumented = true

      it "passes if a documented method has a return type" do
        expect_no_issues rule, <<-CRYSTAL
          # This method is documented
          def hello : String
            "hello world"
          end

          # This method is documented
          private def hello : String
            "hello world"
          end

          # This method is documented
          protected def hello : String
            "hello world"
          end
          CRYSTAL
      end

      it "passes if undocumented private or protected methods have a return type" do
        expect_no_issues rule, <<-CRYSTAL
          private def hello
            "hello world"
          end

          protected def hello
            "hello world"
          end

          CRYSTAL
      end

      it "fails if an undocumented method doesn't have a return type" do
        expect_issue rule, <<-CRYSTAL
          def hello
            # ^^^^^ error: Methods should have a return type restriction
            "hello world"
          end

          # :nodoc:
          def hello
            # ^^^^^ error: Methods should have a return type restriction
            "hello world"
          end
          CRYSTAL
      end
    end
  end
end
