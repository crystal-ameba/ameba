require "../../../spec_helper"

module Ameba::Rule::Style
  describe HeredocEscape do
    subject = HeredocEscape.new

    it "passes if a heredoc doesn't contain interpolation" do
      expect_no_issues subject, %{
        <<-HEREDOC
          foo
          HEREDOC
      }
    end

    it "passes if a heredoc contains interpolation" do
      expect_no_issues subject, %{
        <<-HEREDOC
          foo \#{:bar}
          HEREDOC
      }
    end

    it "passes if a heredoc contains normal and escaped interpolation" do
      expect_no_issues subject, %{
        <<-HEREDOC
          foo \\\#{:bar} \#{:baz}
          HEREDOC
      }
    end

    it "fails if a heredoc contains escaped interpolation" do
      expect_issue subject, %{
        <<-HEREDOC
      # ^^^^^^^^^^ error: Use an escaped heredoc
          foo \\\#{:bar}
          HEREDOC
      }
    end

    pending "passes if a heredoc contains normal and escaped escape sequences" do
      expect_no_issues subject, %{
        <<-HEREDOC
          \\t \\n
          \\\\t \\\\n
          HEREDOC
      }
    end

    it "fails if a heredoc contains escaped escape sequences" do
      expect_issue subject, %{
        <<-HEREDOC
      # ^^^^^^^^^^ error: Use an escaped heredoc
          \\\\t \\\\n
          HEREDOC
      }
    end

    it "passes if an escaped heredoc contains interpolation" do
      expect_no_issues subject, %{
        <<-'HEREDOC'
          foo \#{:bar}
          HEREDOC
      }
    end

    it "passes if an escaped heredoc contains escape sequences" do
      expect_no_issues subject, %{
        <<-'HEREDOC'
          foo \\t \\n
          HEREDOC
      }
    end

    it "fails if an escaped heredoc doesn't contain interpolation" do
      expect_issue subject, %{
        <<-'HEREDOC'
      # ^^^^^^^^^^^^ error: Unnecessary heredoc escape
          foo
          HEREDOC
      }
    end
  end
end
