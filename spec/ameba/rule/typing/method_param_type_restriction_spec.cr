require "../../../spec_helper"

module Ameba::Rule::Typing
  subject = MethodParamTypeRestriction.new
  subject.private_methods = true
  subject.protected_methods = true
  subject.undocumented = true

  it "passes if a method param has a type" do
    expect_no_issues subject, <<-CRYSTAL
      def hello(a : String) : String
        "hello world" + a
      end
      CRYSTAL
  end

  it "fails if a method param doesn't have a type" do
    expect_issue subject, <<-CRYSTAL
      def hello(a)
              # ^ error: Method parameters require a type restriction
        "hello world" + a
      end
      CRYSTAL
  end

  it "fails if a private method method param doesn't have a type" do
    expect_issue subject, <<-CRYSTAL
      class Greeter
        private def hello(a)
                        # ^ error: Method parameters require a type restriction
          "hello world" + a
        end
      end
      CRYSTAL
  end

  it "fails if a protected method param doesn't have a type" do
    expect_issue subject, <<-CRYSTAL
      class Greeter
        protected def hello(a)
                          # ^ error: Method parameters require a type restriction
          "hello world" + a
        end
      end
      CRYSTAL
  end

  context "properties" do
    context "#private_methods" do
      it "allows relaxing restriction requirement for private methods" do
        rule = MethodParamTypeRestriction.new
        rule.private_methods = false

        expect_no_issues rule, <<-CRYSTAL
          class Greeter
            private def hello
              "hello world"
            end
          end
          CRYSTAL
      end
    end

    context "#protected_methods" do
      it "allows relaxing restriction requirement for protected methods" do
        rule = MethodParamTypeRestriction.new
        rule.protected_methods = false

        expect_no_issues rule, <<-CRYSTAL
          class Greeter
            protected def hello
              "hello world"
            end
          end
          CRYSTAL
      end
    end

    context "#undocumented" do
      rule = MethodParamTypeRestriction.new
      rule.undocumented = false

      it "allows relaxing restriction requirement for undocumented methods" do
        expect_no_issues rule, <<-CRYSTAL
          class Greeter
            def hello(a)
              "hello world"
            end
          end
          CRYSTAL
      end

      it "allows relaxing restriction requirement for methods with a :nodoc: directive" do
        expect_no_issues rule, <<-CRYSTAL
          class Greeter
            # :nodoc:
            def hello(a)
              "hello world"
            end
          end
          CRYSTAL
      end

      it "fails if a documented method param doesn't have a type" do
        expect_issue subject, <<-CRYSTAL
          # This is documentation about `hello`
          def hello(a)
                  # ^ error: Method parameters require a type restriction
            "hello world" + a
          end
          CRYSTAL
      end
    end
  end
end
