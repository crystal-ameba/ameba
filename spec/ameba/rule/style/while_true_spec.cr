require "../../../spec_helper"

module Ameba::Rule::Style
  subject = WhileTrue.new

  describe WhileTrue do
    it "passes if there is no `while true`" do
      expect_no_issues subject, <<-CRYSTAL
        a = 1
        loop do
          a += 1
          break if a > 5
        end
        CRYSTAL
    end

    it "fails if there is `while true`" do
      source = expect_issue subject, <<-CRYSTAL
        a = 1
        while true
        # ^^^^^^^^ error: While statement using true literal as condition
          a += 1
          break if a > 5
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        a = 1
        loop do
          a += 1
          break if a > 5
        end
        CRYSTAL
    end
  end
end
