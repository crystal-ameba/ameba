require "../../../spec_helper"

module Ameba::Rule::Naming
  subject = BlockParameterName.new
    .tap(&.min_name_length = 3)
    .tap(&.allowed_names = %w[e i j k v])

  describe BlockParameterName do
    it "passes if block parameter name matches #allowed_names" do
      subject.allowed_names.each do |name|
        expect_no_issues subject, <<-CRYSTAL
          %w[].each { |#{name}| }
          CRYSTAL
      end
    end

    it "passes if block parameter name starts with '_'" do
      expect_no_issues subject, <<-CRYSTAL
        %w[].each { |_, _foo, _bar| }
        CRYSTAL
    end

    it "fails if block parameter name doesn't match #allowed_names" do
      expect_issue subject, <<-CRYSTAL
        %w[].each { |x| }
                   # ^ error: Disallowed block parameter name found
        CRYSTAL
    end

    context "properties" do
      context "#min_name_length" do
        it "allows setting custom values" do
          rule = BlockParameterName.new
          rule.allowed_names = %w[a b c]

          rule.min_name_length = 3
          expect_issue rule, <<-CRYSTAL
            %w[].each { |x| }
                       # ^ error: Disallowed block parameter name found
            CRYSTAL

          rule.min_name_length = 1
          expect_no_issues rule, <<-CRYSTAL
            %w[].each { |x| }
            CRYSTAL
        end
      end

      context "#allow_names_ending_in_numbers" do
        it "allows setting custom values" do
          rule = BlockParameterName.new
          rule.min_name_length = 1
          rule.allowed_names = %w[]

          rule.allow_names_ending_in_numbers = false
          expect_issue rule, <<-CRYSTAL
            %w[].each { |x1| }
                       # ^ error: Disallowed block parameter name found
            CRYSTAL

          rule.allow_names_ending_in_numbers = true
          expect_no_issues rule, <<-CRYSTAL
            %w[].each { |x1| }
            CRYSTAL
        end
      end

      context "#allowed_names" do
        it "allows setting custom names" do
          rule = BlockParameterName.new
          rule.min_name_length = 3

          rule.allowed_names = %w[a b c]
          expect_issue rule, <<-CRYSTAL
            %w[].each { |x| }
                       # ^ error: Disallowed block parameter name found
            CRYSTAL

          rule.allowed_names = %w[x y z]
          expect_no_issues rule, <<-CRYSTAL
            %w[].each { |x| }
            CRYSTAL
        end
      end

      context "#forbidden_names" do
        it "allows setting custom names" do
          rule = BlockParameterName.new
          rule.min_name_length = 1
          rule.allowed_names = %w[]

          rule.forbidden_names = %w[x y z]
          expect_issue rule, <<-CRYSTAL
            %w[].each { |x| }
                       # ^ error: Disallowed block parameter name found
            CRYSTAL

          rule.forbidden_names = %w[a b c]
          expect_no_issues rule, <<-CRYSTAL
            %w[].each { |x| }
            CRYSTAL
        end
      end
    end
  end
end
