require "../../../spec_helper"

module Ameba::Rule::Naming
  describe BinaryOperatorParameterName do
    subject = BinaryOperatorParameterName.new

    it "ignores `other` parameter name in binary method definitions" do
      expect_no_issues subject, <<-CRYSTAL
        def +(other); end
        def -(other); end
        def *(other); end
        CRYSTAL
    end

    it "ignores binary method definitions with arity other than 1" do
      expect_no_issues subject, <<-CRYSTAL
        def +; end
        def +(foo, bar); end
        def -; end
        def -(foo, bar); end
        CRYSTAL
    end

    it "ignores non-binary method definitions" do
      expect_no_issues subject, <<-CRYSTAL
        def foo(bar); end
        def bąk(genus); end
        CRYSTAL
    end

    it "reports binary methods definitions with incorrectly named parameter" do
      expect_issue subject, <<-CRYSTAL
        def +(foo); end
            # ^^^ error: When defining the `+` operator, name its argument `other`
        def -(foo); end
            # ^^^ error: When defining the `-` operator, name its argument `other`
        def *(foo); end
            # ^^^ error: When defining the `*` operator, name its argument `other`
        CRYSTAL
    end

    it "ignores methods from #excluded_operators" do
      subject.excluded_operators.each do |op|
        expect_no_issues subject, <<-CRYSTAL
          def #{op}(foo); end
          CRYSTAL
      end
    end

    context "properties" do
      context "#allowed_names" do
        it "uses `other` as the default" do
          expect_issue subject, <<-CRYSTAL
            def +(foo); end
                # ^^^ error: When defining the `+` operator, name its argument `other`
            CRYSTAL
        end

        it "allows setting custom names" do
          rule = BinaryOperatorParameterName.new

          rule.allowed_names = %w[a b c]
          expect_issue rule, <<-CRYSTAL
            def +(foo); end
                # ^^^ error: When defining the `+` operator, name its argument `a` or `b` or `c`
            CRYSTAL

          rule.allowed_names = %w[foo bar baz]
          expect_no_issues rule, <<-CRYSTAL
            def +(foo); end
            def -(bar); end
            def /(baz); end
            CRYSTAL
        end
      end
    end
  end
end
