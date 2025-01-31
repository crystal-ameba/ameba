require "../../../spec_helper"

module Ameba::Rule::Style
  describe HeredocIndent do
    subject = HeredocIndent.new

    it "passes if heredoc body indented one level" do
      expect_no_issues subject, <<-CRYSTAL
        <<-HEREDOC
          hello world
          HEREDOC

          <<-HEREDOC
            hello world
            HEREDOC
        CRYSTAL
    end

    it "fails if the heredoc body is indented incorrectly" do
      expect_issue subject, <<-CRYSTAL
        <<-ONE
        # ^^^^ error: Heredoc body should be indented by 2 spaces
        hello world
        ONE

          <<-TWO
        # ^^^^^^ error: Heredoc body should be indented by 2 spaces
          hello world
          TWO

          <<-THREE
        # ^^^^^^^^ error: Heredoc body should be indented by 2 spaces
             hello world
             THREE

          <<-FOUR
        # ^^^^^^^ error: Heredoc body should be indented by 2 spaces
        hello world
        FOUR
        CRYSTAL
    end

    context "properties" do
      context "#indent_by" do
        rule = HeredocIndent.new
        rule.indent_by = 0

        it "passes if heredoc body has the same indent level" do
          expect_no_issues rule, <<-CRYSTAL
            <<-HEREDOC
            hello world
            HEREDOC

              <<-HEREDOC
              hello world
              HEREDOC
            CRYSTAL
        end

        it "fails if the heredoc body is indented incorrectly" do
          expect_issue rule, <<-CRYSTAL
            <<-ONE
            # ^^^^ error: Heredoc body should be indented by 0 spaces
              hello world
              ONE

              <<-TWO
            # ^^^^^^ error: Heredoc body should be indented by 0 spaces
                hello world
                TWO

              <<-FOUR
            # ^^^^^^^ error: Heredoc body should be indented by 0 spaces
            hello world
            FOUR
            CRYSTAL
        end
      end
    end
  end
end
