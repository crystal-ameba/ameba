require "../../../spec_helper"

module Ameba::Rule::Typing
  describe MethodParameterTypeRestriction do
    subject = MethodParameterTypeRestriction.new

    it "passes if a method parameter has a type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        def hello(a : String, b : _) : String
          "hello world" + a + b
        end

        def hello(*a : String) : String
          "hello world" + a.join(", ")
        end
        CRYSTAL
    end

    it "fails if a splat method parameter with a name doesn't have a type restriction" do
      expect_issue subject, <<-CRYSTAL
        def hello(*a) : String
                 # ^ error: Method parameter should have a type restriction
          "hello world" + a.join(", ")
        end
        CRYSTAL
    end

    it "passes if a splat parameter without a name doesn't have a type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        def hello(hello : String, *, world : String = "world") : String
          hello + world
        end
        CRYSTAL
    end

    it "passes if a double splat method parameter doesn't have a type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        def hello(a : String, **world) : String
          "hello world" + a
        end
        CRYSTAL
    end

    it "passes if a private method parameter doesn't have a type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        private def hello(a)
          "hello world" + a
        end
        CRYSTAL
    end

    it "passes if a protected method parameter doesn't have a type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        protected def hello(a)
          "hello world" + a
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
        def hello(a)
                # ^ error: Method parameter should have a type restriction
          "hello world" + a
        end

        def hello(a, ext b)
                # ^ error: Method parameter should have a type restriction
                   # ^ error: Method parameter should have a type restriction
          "hello world" + a + b
        end
        CRYSTAL
    end

    it "passes if a method parameter with a default value doesn't have a type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        def hello(a = "jim")
          "hello there, " + a
        end
        CRYSTAL
    end

    it "passes if a block parameter doesn't have a type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        def hello(&)
          "hello there"
        end
        CRYSTAL
    end

    context "properties" do
      context "#private_methods" do
        rule = MethodParameterTypeRestriction.new
        rule.private_methods = true

        it "passes if a method has a parameter type restriction" do
          expect_no_issues rule, <<-CRYSTAL
            private def hello(a : String) : String
              "hello world" + a
            end
            CRYSTAL
        end

        it "passes if a protected method parameter doesn't have a type restriction" do
          expect_no_issues rule, <<-CRYSTAL
            protected def hello(a)
              "hello world"
            end
            CRYSTAL
        end

        it "fails if a public or private method doesn't have a parameter type restriction" do
          expect_issue rule, <<-CRYSTAL
            def hello(a)
                    # ^ error: Method parameter should have a type restriction
              "hello world"
            end

            private def hello(a)
                            # ^ error: Method parameter should have a type restriction
              "hello world"
            end
            CRYSTAL
        end
      end

      context "#protected_methods" do
        rule = MethodParameterTypeRestriction.new
        rule.protected_methods = true

        it "passes if a method has a parameter type restriction" do
          expect_no_issues rule, <<-CRYSTAL
            protected def hello(a : String) : String
              "hello world" + a
            end
            CRYSTAL
        end

        it "passes if a private method parameter doesn't have a type restriction" do
          expect_no_issues rule, <<-CRYSTAL
            private def hello(a)
              "hello world"
            end
            CRYSTAL
        end

        it "fails if a public or protected method doesn't have a parameter type restriction" do
          expect_issue rule, <<-CRYSTAL
            def hello(a)
                    # ^ error: Method parameter should have a type restriction
              "hello world"
            end

            protected def hello(a)
                              # ^ error: Method parameter should have a type restriction
              "hello world"
            end
            CRYSTAL
        end
      end

      context "#default_value" do
        it "fails if a method parameter with a default value doesn't have a type restriction" do
          rule = MethodParameterTypeRestriction.new
          rule.default_value = true

          expect_issue rule, <<-'CRYSTAL'
            def hello(a = "world")
                    # ^ error: Method parameter should have a type restriction
              "hello #{a}"
            end
            CRYSTAL
        end
      end

      context "#block_parameters" do
        rule = MethodParameterTypeRestriction.new
        rule.block_parameters = true

        it "fails if a block parameter without a name doesn't have a type restriction" do
          expect_issue rule, <<-CRYSTAL
            def hello(&)
                     # ^ error: Method parameter should have a type restriction
              "hello"
            end
            CRYSTAL
        end

        it "fails if a block parameter with a name doesn't have a type restriction" do
          expect_issue rule, <<-'CRYSTAL'
            def hello(&a)
                     # ^ error: Method parameter should have a type restriction
              "hello, #{a.call}"
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
