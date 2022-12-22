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
      source = expect_issue subject, <<-CRYSTAL
        unless something
        # ^^^^^^^^^^^^^^ error: Favour if over unless with else
          :one
        else
          :two
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        if something
          :two
        else
          :one
        end
        CRYSTAL
    end
  end
end
