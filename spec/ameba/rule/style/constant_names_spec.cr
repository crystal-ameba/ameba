require "../../../spec_helper"

module Ameba
  subject = Rule::Style::ConstantNames.new

  private def it_reports_constant(name, value, expected)
    it "reports constant name #{expected}" do
      rule = Rule::Style::ConstantNames.new
      expect_issue rule, <<-CRYSTAL, name: name
          %{name} = #{value}
        # ^{name} error: Constant name should be screaming-cased: #{expected}, not #{name}
        CRYSTAL
    end
  end

  describe Rule::Style::ConstantNames do
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

    it "reports rule, pos and message" do
      s = Source.new %(
        Const_Name = 1
      ), "source.cr"
      subject.catch(s).should_not be_valid
      issue = s.issues.first
      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:1:1"
      issue.end_location.to_s.should eq "source.cr:1:10"
      issue.message.should eq(
        "Constant name should be screaming-cased: CONST_NAME, not Const_Name"
      )
    end
  end
end
