require "../../../spec_helper"

module Ameba::Rule::Naming
  subject = BinaryOperatorParameterName.new

  describe BinaryOperatorParameterName do
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
            # ^ error: When defining the `+` operator, name its argument `other`
        def -(foo); end
            # ^ error: When defining the `-` operator, name its argument `other`
        def *(foo); end
            # ^ error: When defining the `*` operator, name its argument `other`
        CRYSTAL
    end

    it "ignores methods from #excluded_operators" do
      subject.excluded_operators.each do |op|
        expect_no_issues subject, <<-CRYSTAL
          def #{op}(foo); end
          CRYSTAL
      end
    end
  end
end
