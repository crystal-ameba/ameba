require "../../../spec_helper"

module Ameba
  subject = Rule::Naming::ConstantNames.new

  private def it_reports_constant(name, value, expected, *, file = __FILE__, line = __LINE__)
    it "reports constant name #{expected}", file, line do
      rule = Rule::Naming::ConstantNames.new
      expect_issue rule, <<-CRYSTAL, name: name, file: file, line: line
          %{name} = #{value}
        # ^{name} error: Constant name should be screaming-cased: #{expected}, not #{name}
        CRYSTAL
    end
  end

  describe Rule::Naming::ConstantNames do
    it "passes if type names are screaming-cased" do
      expect_no_issues subject, <<-CRYSTAL
        LUCKY_NUMBERS     = [3, 7, 11]
        DOCUMENTATION_URL = "https://crystal-lang.org/docs"

        Int32

        s : String = "str"

        def works(n : Int32)
        end

        Log = ::Log.for("db")

        a = 1
        myVar = 2
        m_var = 3
        CRYSTAL
    end

    # it_reports_constant "MyBadConstant", "1", "MYBADCONSTANT"
    it_reports_constant "Wrong_NAME", "2", "WRONG_NAME"
    it_reports_constant "Wrong_Name", "3", "WRONG_NAME"
  end
end
