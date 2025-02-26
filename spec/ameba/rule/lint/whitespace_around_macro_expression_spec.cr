require "../../../spec_helper"

module Ameba::Rule::Lint
  describe WhitespaceAroundMacroExpression do
    subject = WhitespaceAroundMacroExpression.new

    it "passes if macro expression is wrapped with whitespace" do
      expect_no_issues subject, <<-CRYSTAL
        {{ foo }}
        CRYSTAL
    end

    it "reports macro expression without whitespace around" do
      source = expect_issue subject, <<-CRYSTAL
        {{foo}}
        # ^^^^^ error: Missing spaces around macro expression
        {{ bar}}
        # ^^^^^^ error: Missing spaces around macro expression
        {{baz }}
        # ^^^^^^ error: Missing spaces around macro expression
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        {{ foo }}
        {{ bar }}
        {{ baz }}
        CRYSTAL
    end

    # https://github.com/crystal-lang/crystal/pull/15524
    it "reports macro expression without whitespace around within a macro body" do
      source = expect_issue subject, <<-CRYSTAL
        {% begin %}
          {{foo}}
        # ^^^^^^^ error: Missing spaces around macro expression
          {{ bar}}
        # ^^^^^^^^ error: Missing spaces around macro expression
          {{baz }}
        # ^^^^^^^^ error: Missing spaces around macro expression
        {% end %}
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        {% begin %}
          {{ foo }}
          {{ bar }}
          {{ baz }}
        {% end %}
        CRYSTAL
    end
  end
end
