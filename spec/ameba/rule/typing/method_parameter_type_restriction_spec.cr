require "../../../spec_helper"

module Ameba::Rule::Typing
  describe MethodParameterTypeRestriction do
    subject = MethodParameterTypeRestriction.new

    it "passes if a method parameter has a type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        def foo(bar : String, baz : _) : String
        end
        CRYSTAL
    end

    it "passes if a splat method parameter has a type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        def foo(*bar : String) : String
        end
        CRYSTAL
    end

    it "fails if a splat method parameter with a name doesn't have a type restriction" do
      expect_issue subject, <<-CRYSTAL
        def foo(*bar) : String
               # ^ error: Method parameter should have a type restriction
        end
        CRYSTAL
    end

    it "passes if a splat parameter without a name doesn't have a type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        def foo(bar : String, *, baz : String = "bat") : String
        end
        CRYSTAL
    end

    it "passes if a double splat method parameter doesn't have a type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        def foo(bar : String, **opts) : String
        end
        CRYSTAL
    end

    it "passes if a private method parameter doesn't have a type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        private def foo(bar)
        end
        CRYSTAL
    end

    it "passes if a protected method parameter doesn't have a type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        protected def foo(bar)
        end
        CRYSTAL
    end

    it "passes if a method has a `:nodoc:` annotation" do
      expect_no_issues subject, <<-CRYSTAL
        # :nodoc:
        def foo(bar); end
        CRYSTAL
    end

    it "fails if a public method parameter doesn't have a type restriction" do
      expect_issue subject, <<-CRYSTAL
        def foo(bar)
              # ^ error: Method parameter should have a type restriction
        end
        CRYSTAL
    end

    it "fails if a public method external parameter doesn't have a type restriction" do
      expect_issue subject, <<-CRYSTAL
        def foo(bar, ext baz)
              # ^ error: Method parameter should have a type restriction
                   # ^ error: Method parameter should have a type restriction
        end
        CRYSTAL
    end

    it "passes if a method parameter with a default value doesn't have a type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        def foo(bar = "baz")
        end
        CRYSTAL
    end

    it "passes if a block parameter doesn't have a type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        def foo(&)
        end
        CRYSTAL
    end

    context "properties" do
      context "#private_methods" do
        rule = MethodParameterTypeRestriction.new
        rule.private_methods = true

        it "passes if a method has a parameter type restriction" do
          expect_no_issues rule, <<-CRYSTAL
            private def foo(bar : String) : String
            end
            CRYSTAL
        end

        it "passes if a protected method parameter doesn't have a type restriction" do
          expect_no_issues rule, <<-CRYSTAL
            protected def foo(bar)
            end
            CRYSTAL
        end

        it "fails if a public method doesn't have a parameter type restriction" do
          expect_issue rule, <<-CRYSTAL
            def foo(bar)
                  # ^ error: Method parameter should have a type restriction
            end
            CRYSTAL
        end

        it "fails if a private method doesn't have a parameter type restriction" do
          expect_issue rule, <<-CRYSTAL
            private def foo(bar)
                          # ^ error: Method parameter should have a type restriction
            end
            CRYSTAL
        end
      end

      context "#protected_methods" do
        rule = MethodParameterTypeRestriction.new
        rule.protected_methods = true

        it "passes if a method has a parameter type restriction" do
          expect_no_issues rule, <<-CRYSTAL
            protected def foo(bar : String) : String
            end
            CRYSTAL
        end

        it "passes if a private method parameter doesn't have a type restriction" do
          expect_no_issues rule, <<-CRYSTAL
            private def foo(bar)
            end
            CRYSTAL
        end

        it "fails if a public method doesn't have a parameter type restriction" do
          expect_issue rule, <<-CRYSTAL
            def foo(bar)
                  # ^ error: Method parameter should have a type restriction
            end
            CRYSTAL
        end

        it "fails if a protected method doesn't have a parameter type restriction" do
          expect_issue rule, <<-CRYSTAL
            protected def foo(bar)
                            # ^ error: Method parameter should have a type restriction
            end
            CRYSTAL
        end
      end

      context "#default_value" do
        it "fails if a method parameter with a default value doesn't have a type restriction" do
          rule = MethodParameterTypeRestriction.new
          rule.default_value = true

          expect_issue rule, <<-CRYSTAL
            def foo(bar = "baz")
                  # ^ error: Method parameter should have a type restriction
            end
            CRYSTAL
        end
      end

      context "#block_parameters" do
        rule = MethodParameterTypeRestriction.new
        rule.block_parameters = true

        it "fails if a block parameter without a name doesn't have a type restriction" do
          expect_issue rule, <<-CRYSTAL
            def foo(&)
                   # ^ error: Method parameter should have a type restriction
            end
            CRYSTAL
        end

        it "fails if a block parameter with a name doesn't have a type restriction" do
          expect_issue rule, <<-CRYSTAL
            def foo(&block)
                   # ^ error: Method parameter should have a type restriction
            end
            CRYSTAL
        end
      end

      context "#nodoc_methods" do
        rule = MethodParameterTypeRestriction.new
        rule.nodoc_methods = true

        it "fails if a public method parameter doesn't have a type restriction" do
          expect_issue rule, <<-CRYSTAL
            # :nodoc:
            def foo(bar)
                  # ^ error: Method parameter should have a type restriction
            end
            CRYSTAL
        end
      end
    end
  end
end
