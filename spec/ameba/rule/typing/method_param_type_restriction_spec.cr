require "../../../spec_helper"

module Ameba::Rule::Typing
  subject = MethodParamTypeRestriction.new

  it "passes if a method param has a type restriction" do
    expect_no_issues subject, <<-CRYSTAL
      def hello(a : String) : String
        "hello world" + a
      end
      CRYSTAL
  end

  it "passes if a private method method param doesn't have a type restriction" do
    expect_no_issues subject, <<-CRYSTAL
      private def hello(a)
        "hello world" + a
      end
      CRYSTAL
  end

  it "passes if a protected method param doesn't have a type restriction" do
    expect_no_issues subject, <<-CRYSTAL
      protected def hello(a)
        "hello world" + a
      end
      CRYSTAL
  end

  it "fails if a public method param doesn't have a type restriction" do
    expect_issue subject, <<-CRYSTAL
      def hello(a)
              # ^ error: Method parameter should have a type restriction
        "hello world" + a
      end
      CRYSTAL
  end

  it "passes if a method param with a default value doesn't have a type restriction" do
    expect_no_issues subject, <<-CRYSTAL
      def hello(a = "jim")
        "hello there, " + a
      end
      CRYSTAL
  end

  context "properties" do
    context "#private_methods" do
      rule = MethodParamTypeRestriction.new
      rule.private_methods = true

      it "passes if a method has a return type restriction" do
        expect_no_issues rule, <<-CRYSTAL
          private def hello(a : String) : String
            "hello world" + a
          end
          CRYSTAL
      end

      it "passes if a protected method param doesn't have a type restriction" do
        expect_no_issues rule, <<-CRYSTAL
          protected def hello(a)
            "hello world"
          end
          CRYSTAL
      end

      it "fails if a public or private method doesn't have a return type restriction" do
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
      rule = MethodParamTypeRestriction.new
      rule.protected_methods = true

      it "passes if a method has a return type restriction" do
        expect_no_issues rule, <<-CRYSTAL
          protected def hello(a : String) : String
            "hello world" + a
          end
          CRYSTAL
      end

      it "passes if a private method param doesn't have a type restriction" do
        expect_no_issues rule, <<-CRYSTAL
          private def hello(a)
            "hello world"
          end
          CRYSTAL
      end

      it "fails if a public or protected method doesn't have a return type restriction" do
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
      it "fails if a method param with a default value doesn't have a type restriction" do
        rule = MethodParamTypeRestriction.new
        rule.default_value = true

        expect_issue rule, <<-CRYSTAL
          def hello(a = "world")
                  # ^ error: Method parameter should have a type restriction
            "hello \#{a}"
          end
          CRYSTAL
      end
    end
  end
end
