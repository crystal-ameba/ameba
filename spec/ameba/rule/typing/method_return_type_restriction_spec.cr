require "../../../spec_helper"

module Ameba::Rule::Typing
  describe MethodReturnTypeRestriction do
    subject = MethodReturnTypeRestriction.new

    it "passes if a method has a return type restriction" do
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

    it "passes if a private or protected method doesn't have a return type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        private def hello
          "hello world"
        end

        protected def hello
          "hello world"
        end
        CRYSTAL
    end

    it "passes if a method has a `:nodoc:` annotation" do
      expect_no_issues subject, <<-CRYSTAL
        # :nodoc:
        def foo; end
        CRYSTAL
    end

    it "fails if a public method doesn't have a return type restriction" do
      expect_issue subject, <<-CRYSTAL
        def hello
        # ^^^^^^^ error: Method should have a return type restriction
          "hello world"
        end
        CRYSTAL
    end

    context "properties" do
      context "#private_methods" do
        rule = MethodReturnTypeRestriction.new
        rule.private_methods = true

        it "passes if a method has a return type restriction" do
          expect_no_issues rule, <<-CRYSTAL
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

        it "passes if a protected method doesn't have a return type restriction" do
          expect_no_issues rule, <<-CRYSTAL
            protected def hello
              "hello world"
            end
            CRYSTAL
        end

        it "fails if a public or private method doesn't have a return type restriction" do
          expect_issue rule, <<-CRYSTAL
            def hello
            # ^^^^^^^ error: Method should have a return type restriction
              "hello world"
            end

            private def hello
                  # ^^^^^^^^^ error: Method should have a return type restriction
              "hello world"
            end
            CRYSTAL
        end
      end

      context "#protected_methods" do
        rule = MethodReturnTypeRestriction.new
        rule.protected_methods = true

        it "passes if a method has a return type restriction" do
          expect_no_issues rule, <<-CRYSTAL
            protected def hello : String
              "hello world"
            end
            CRYSTAL
        end

        it "passes if a private method doesn't have a return type restriction" do
          expect_no_issues rule, <<-CRYSTAL
            private def hello
              "hello world"
            end
            CRYSTAL
        end

        it "fails if a public or protected method doesn't have a return type restriction" do
          expect_issue rule, <<-CRYSTAL
            def hello
            # ^^^^^^^ error: Method should have a return type restriction
              "hello world"
            end

            protected def hello
                    # ^^^^^^^^^ error: Method should have a return type restriction
              "hello world"
            end
            CRYSTAL
        end
      end

      context "#nodoc_methods" do
        rule = MethodReturnTypeRestriction.new
        rule.nodoc_methods = true

        it "fails if a public method doesn't have a return type restriction" do
          expect_issue rule, <<-CRYSTAL
            # :nodoc:
            def foo
            # ^^^^^ error: Method should have a return type restriction
            end
            CRYSTAL
        end
      end
    end
  end
end
