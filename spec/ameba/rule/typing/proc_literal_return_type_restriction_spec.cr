require "../../../spec_helper"

module Ameba::Rule::Typing
  describe ProcLiteralReturnTypeRestriction do
    subject = ProcLiteralReturnTypeRestriction.new

    it "passes if a proc literal has a return type restriction" do
      expect_no_issues subject, <<-CRYSTAL
        foo = -> (bar : String) : Nil { }
        CRYSTAL
    end

    it "fails if a proc literal doesn't have a return type restriction" do
      expect_issue subject, <<-CRYSTAL
        foo = -> (bar : String) { }
            # ^^^^^^^^^^^^^^^^^^^^^ error: Proc literal should have a return type restriction
        CRYSTAL
    end
  end
end
