require "../../../spec_helper"

module Ameba::Rule::Typing
  subject = MethodReturnTypeRestriction.new
  subject.private_methods = true
  subject.protected_methods = true
  subject.undocumented = true

  it "passes if a method has a return type" do
    expect_no_issues subject, <<-CRYSTAL
      def hello : String
        "hello world"
      end
      CRYSTAL
  end

  it "fails if a method doesn't have a return type" do
    expect_issue subject, <<-CRYSTAL
      def hello
        # ^^^^^ error: Methods require a return type restriction
        "hello world"
      end
      CRYSTAL
  end

  it "fails if a private method doesn't have a return type" do
    expect_issue subject, <<-CRYSTAL
      class Greeter
        private def hello
                  # ^^^^^ error: Methods require a return type restriction
          "hello world"
        end
      end
      CRYSTAL
  end

  it "fails if a protected method doesn't have a return type" do
    expect_issue subject, <<-CRYSTAL
      class Greeter
        protected def hello
                    # ^^^^^ error: Methods require a return type restriction
          "hello world"
        end
      end
      CRYSTAL
  end

  it "fails if a documented method doesn't have a return type" do
    expect_issue subject, <<-CRYSTAL
      # This is documentation about `hello`
      def hello(a)
        # ^^^^^ error: Methods require a return type restriction
        "hello world" + a
      end
      CRYSTAL
  end

  context "properties" do
    context "#private_methods" do
      it "allows relaxing restriction requirement for private methods" do
        rule = MethodReturnTypeRestriction.new
        rule.undocumented = true
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
        rule = MethodReturnTypeRestriction.new
        rule.undocumented = true
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
      rule = MethodReturnTypeRestriction.new
      rule.undocumented = false

      it "allows relaxing restriction requirement for undocumented methods" do
        expect_no_issues rule, <<-CRYSTAL
          class Greeter
            def hello
              "hello world"
            end
          end
          CRYSTAL
      end

      it "allows relaxing restriction requirement for methods with a :nodoc: directive" do
        expect_no_issues rule, <<-CRYSTAL
          class Greeter
            # :nodoc:
            def hello
              "hello world"
            end
          end
          CRYSTAL
      end
    end
  end
end
