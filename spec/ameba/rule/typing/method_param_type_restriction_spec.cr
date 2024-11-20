require "../../../spec_helper"

module Ameba::Rule::Typing
  subject = MethodParamTypeRestriction.new

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

  it "fails if a protected method doesn't have a return type" do
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
  end
end
