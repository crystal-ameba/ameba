require "../../../spec_helper"

module Ameba::Rule::Style
  describe HeredocEscape do
    subject = HeredocEscape.new

    it "passes if a heredoc doesn't contain interpolation" do
      expect_no_issues subject, <<-CRYSTAL
        <<-HEREDOC
          foo
          HEREDOC
        CRYSTAL
    end

    it "passes if a heredoc contains interpolation" do
      expect_no_issues subject, <<-'CRYSTAL'
        <<-HEREDOC
          foo #{:bar}
          HEREDOC
        CRYSTAL
    end

    it "passes if a heredoc contains normal and escaped interpolation" do
      expect_no_issues subject, <<-'CRYSTAL'
        <<-HEREDOC
          foo \#{:bar} #{:baz}
          HEREDOC
        CRYSTAL
    end

    it "passes if a heredoc contains an escape sequence and escaped interpolation" do
      expect_no_issues subject, <<-'CRYSTAL'
        <<-HEREDOC
          foo \t \#{:baz}
          HEREDOC
        CRYSTAL
    end

    it "passes if a heredoc contains an escaped escape sequence and interpolation" do
      expect_no_issues subject, <<-'CRYSTAL'
        <<-HEREDOC
          foo \\t #{:baz}
          HEREDOC
        CRYSTAL
    end

    it "fails if a heredoc contains escaped interpolation" do
      expect_issue subject, <<-'CRYSTAL'
        <<-HEREDOC
        # ^^^^^^^^ error: Use an escaped heredoc marker: `<<-'HEREDOC'`
          foo \#{:bar}
          HEREDOC
        CRYSTAL
    end

    it "fails if a heredoc contains escaped interpolation and escaped escape sequences" do
      expect_issue subject, <<-'CRYSTAL'
        <<-HEREDOC
        # ^^^^^^^^ error: Use an escaped heredoc marker: `<<-'HEREDOC'`
          foo \\t \#{:bar}
          HEREDOC
        CRYSTAL
    end

    it "passes if a heredoc contains normal and escaped escape sequences" do
      expect_no_issues subject, <<-'CRYSTAL'
        <<-HEREDOC
          foo \t \n | \\t \\n
          HEREDOC
        CRYSTAL
    end

    it "fails if a heredoc contains escaped escape sequences" do
      expect_issue subject, <<-'CRYSTAL'
        <<-HEREDOC
        # ^^^^^^^^ error: Use an escaped heredoc marker: `<<-'HEREDOC'`
          \\t \\n
          HEREDOC
        CRYSTAL
    end

    it "passes if an escaped heredoc contains interpolation" do
      expect_no_issues subject, <<-'CRYSTAL'
        <<-'HEREDOC'
          foo #{:bar}
          HEREDOC
        CRYSTAL
    end

    it "passes if an escaped heredoc contains escape sequences" do
      expect_no_issues subject, <<-'CRYSTAL'
        <<-'HEREDOC'
          foo \t \n
          HEREDOC
        CRYSTAL
    end

    it "fails if an escaped heredoc doesn't contain interpolation" do
      expect_issue subject, <<-CRYSTAL
        <<-'HEREDOC'
        # ^^^^^^^^^^ error: Use an unescaped heredoc marker: `<<-HEREDOC`
          foo
          HEREDOC
        CRYSTAL
    end
  end
end
