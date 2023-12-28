require "../../../spec_helper"

module Ameba::Rule::Naming
  subject = RescuedExceptionsVariableName.new

  describe RescuedExceptionsVariableName do
    it "passes if exception handler variable name matches #allowed_names" do
      subject.allowed_names.each do |name|
        expect_no_issues subject, <<-CRYSTAL
          def foo
            raise "foo"
          rescue #{name}
            nil
          end
          CRYSTAL
      end
    end

    it "fails if exception handler variable name doesn't match #allowed_names" do
      expect_issue subject, <<-CRYSTAL
        def foo
          raise "foo"
        rescue wtf
        # ^^^^^^^^ error: Disallowed variable name, use one of these instead: 'e', 'ex', 'exception', 'error'
          nil
        end
        CRYSTAL
    end

    context "properties" do
      context "#allowed_names" do
        it "returns sensible defaults" do
          rule = RescuedExceptionsVariableName.new
          rule.allowed_names.should eq %w[e ex exception error]
        end

        it "allows setting custom names" do
          rule = RescuedExceptionsVariableName.new
          rule.allowed_names = %w[foo]

          expect_issue rule, <<-CRYSTAL
            def foo
              raise "foo"
            rescue e
            # ^^^^^^ error: Disallowed variable name, use 'foo' instead
              nil
            end
            CRYSTAL
        end
      end
    end
  end
end
