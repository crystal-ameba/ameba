require "../../../spec_helper"

module Ameba::Rule::Typing
  describe MethodReturnTypeRestriction do
    subject = MethodReturnTypeRestriction.new

    it "passes if a public method has a return type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        def foo : String
        end
        CRYSTAL
    end

    it "passes if a private method has a return type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        private def foo : String
        end
        CRYSTAL
    end

    it "passes if a protected method has a return type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        protected def foo : String
        end
        CRYSTAL
    end

    it "passes if a private method doesn't have a return type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        private def foo
        end
        CRYSTAL
    end

    it "passes if a protected method doesn't have a return type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        protected def foo
        end
        CRYSTAL
    end

    it "passes if a public method has a `:nodoc:` annotation" do
      expect_no_issues subject, <<-CRYSTAL
        # :nodoc:
        def foo; end
        CRYSTAL
    end

    it "fails if a public method doesn't have a return type restriction" do
      expect_issue subject, <<-CRYSTAL
        def foo
        # ^^^^^ error: Method should have a return type restriction
        end
        CRYSTAL
    end

    context "properties" do
      context "#private_methods" do
        rule = MethodReturnTypeRestriction.new
        rule.private_methods = true

        it "passes if a public method has a return type restriction" do
          expect_no_issues rule, <<-CRYSTAL
            def foo : String
            end
            CRYSTAL
        end

        it "passes if a private method has a return type restriction" do
          expect_no_issues rule, <<-CRYSTAL
            private def foo : String
            end
            CRYSTAL
        end

        it "passes if a protected method has a return type restriction" do
          expect_no_issues rule, <<-CRYSTAL
            protected def foo : String
            end
            CRYSTAL
        end

        it "passes if a protected method doesn't have a return type restriction" do
          expect_no_issues rule, <<-CRYSTAL
            protected def foo
            end
            CRYSTAL
        end

        it "fails if a public method doesn't have a return type restriction" do
          expect_issue rule, <<-CRYSTAL
            def foo
            # ^^^^^ error: Method should have a return type restriction
            end
            CRYSTAL
        end

        it "fails if a private method doesn't have a return type restriction" do
          expect_issue rule, <<-CRYSTAL
            private def foo
                  # ^^^^^^^ error: Method should have a return type restriction
            end
            CRYSTAL
        end
      end

      context "#protected_methods" do
        rule = MethodReturnTypeRestriction.new
        rule.protected_methods = true

        it "passes if a public method has a return type restriction" do
          expect_no_issues rule, <<-CRYSTAL
            def foo : String
            end
            CRYSTAL
        end

        it "passes if a private method doesn't have a return type restriction" do
          expect_no_issues rule, <<-CRYSTAL
            private def foo
            end
            CRYSTAL
        end

        it "passes if a protected method has a return type restriction" do
          expect_no_issues rule, <<-CRYSTAL
            protected def foo : String
            end
            CRYSTAL
        end

        it "fails if a public method doesn't have a return type restriction" do
          expect_issue rule, <<-CRYSTAL
            def foo
            # ^^^^^ error: Method should have a return type restriction
            end
            CRYSTAL
        end

        it "fails if a protected method doesn't have a return type restriction" do
          expect_issue rule, <<-CRYSTAL
            protected def foo
                    # ^^^^^^^ error: Method should have a return type restriction
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
