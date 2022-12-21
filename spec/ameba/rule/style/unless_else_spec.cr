require "../../../spec_helper"

module Ameba::Rule::Style
  subject = UnlessElse.new

  describe UnlessElse do
    it "passes if unless hasn't else" do
      expect_no_issues subject, <<-CRYSTAL
        unless something
          :ok
        end
        CRYSTAL
    end

    it "fails if unless has else" do
      expect_issue subject, <<-CRYSTAL
        unless something
        # ^^^^^^^^^^^^^^ error: Favour if over unless with else
          :one
        else
          :two
        end
        CRYSTAL
    end
  end
end
