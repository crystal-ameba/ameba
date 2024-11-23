require "../../../spec_helper"

module Ameba::Rule::Lint
  describe ReadInstanceVar do
    subject = ReadInstanceVar.new

    it "fails if an instance var is read externally" do
      expect_issue subject, <<-CRYSTAL
        a.@instance_var
        # ^^^^^^^^^^^^^ error: Reading instance variables externally is not allowed.
        CRYSTAL
    end
  end
end
