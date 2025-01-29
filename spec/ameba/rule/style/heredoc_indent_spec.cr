require "../../../spec_helper"

module Ameba::Rule::Style
  describe HeredocIndent do
    subject = HeredocIndent.new

    it "passes if heredoc body indented one level" do
      expect_no_issues subject, <<-CRYSTAL
        call <<-HEREDOC
          hello world
          HEREDOC

          call <<-HEREDOC
            hello world
            HEREDOC
        CRYSTAL
    end

    it "fails if the heredoc body is indented incorrectly" do
      expect_issue subject, <<-CRYSTAL
        call <<-ONE
           # ^^^^^^ error: Heredoc body should be indented by 2 space(s)
        hello world
        ONE

          call <<-TWO
             # ^^^^^^ error: Heredoc body should be indented by 4 space(s)
          hello world
          TWO

          call <<-THREE
             # ^^^^^^^^ error: Heredoc body should be indented by 4 space(s)
             hello world
             THREE

          call <<-FOUR
             # ^^^^^^^ error: Heredoc body should be indented by 4 space(s)
        hello world
        FOUR
        CRYSTAL
    end

    context "properties" do
      context "#same_line" do
        rule = HeredocIndent.new
        rule.same_line = true

        it "passes if heredoc body has the same indent level" do
          expect_no_issues rule, <<-CRYSTAL
            call <<-HEREDOC
            hello world
            HEREDOC

              call <<-HEREDOC
              hello world
              HEREDOC
            CRYSTAL
        end

        it "fails if the heredoc body is indented incorrectly" do
          expect_issue rule, <<-CRYSTAL
            call <<-ONE
               # ^^^^^^ error: Heredoc body should be indented by 0 space(s)
              hello world
              ONE

              call <<-TWO
                 # ^^^^^^ error: Heredoc body should be indented by 2 space(s)
                hello world
                TWO

              call <<-FOUR
                 # ^^^^^^^ error: Heredoc body should be indented by 2 space(s)
            hello world
            FOUR
            CRYSTAL
        end
      end
    end
  end
end
