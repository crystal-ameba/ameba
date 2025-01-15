require "../../../spec_helper"

module Ameba::Rule::Lint
  describe Formatting do
    subject = Formatting.new

    it "passes if source is formatted" do
      expect_no_issues subject, <<-CRYSTAL
        def method(a, b)
          a + b
        end

        CRYSTAL
    end

    it "reports if source is not formatted" do
      source = expect_issue subject, <<-CRYSTAL
        def method(a,b,c=0)
        # ^{} error: Use built-in formatter to format this source
          a+b+c
        end

        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def method(a, b, c = 0)
          a + b + c
        end

        CRYSTAL
    end

    context "properties" do
      context "#fail_on_error" do
        it "passes on formatter errors by default" do
          rule = Formatting.new

          expect_no_issues rule, <<-CRYSTAL
            def method(a, b)
              a + b
            CRYSTAL
        end

        it "reports on formatter errors when enabled" do
          rule = Formatting.new
          rule.fail_on_error = true

          expect_issue rule, <<-CRYSTAL
            def method(a, b)
              a + b
                 # ^ error: Error while formatting: expecting identifier 'end', not 'EOF'
            CRYSTAL
        end
      end
    end
  end
end
