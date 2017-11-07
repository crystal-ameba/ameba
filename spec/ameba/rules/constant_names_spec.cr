require "../../spec_helper"

module Ameba
  subject = Rules::ConstantNames.new

  private def it_reports_constant(code, expected)
    it "reports constant name #{expected}" do
      s = Source.new code
      Rules::ConstantNames.new.catch(s).should_not be_valid
      s.errors.first.message.should contain expected
    end
  end

  describe Rules::ConstantNames do
    it "passes if type names are screaming-cased" do
      s = Source.new %(
        LUCKY_NUMBERS     = [3, 7, 11]
        DOCUMENTATION_URL = "http://crystal-lang.org/docs"

        Int32

        s : String = "str"

        def works(n : Int32)
        end

        a = 1
        myVar = 2
        m_var = 3
      )
      subject.catch(s).should be_valid
    end

    it_reports_constant "MyBadConstant=1", "MYBADCONSTANT"
    it_reports_constant "Wrong_NAME=2", "WRONG_NAME"
    it_reports_constant "Wrong_Name=3", "WRONG_NAME"

    it "reports rule, pos and message" do
      s = Source.new %(
        Const = 1
      ), "source.cr"
      subject.catch(s).should_not be_valid
      error = s.errors.first
      error.rule.should_not be_nil
      error.location.to_s.should eq "source.cr:2:9"
      error.message.should eq(
        "Constant name should be screaming-cased: CONST, not Const"
      )
    end
  end
end
