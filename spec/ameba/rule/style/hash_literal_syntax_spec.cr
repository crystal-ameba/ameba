require "../../../spec_helper"

module Ameba::Rule::Style
  describe HashLiteralSyntax do
    subject = HashLiteralSyntax.new

    it "passes for an hash literal with elements" do
      expect_no_issues subject, <<-CRYSTAL
        {1 => 2, 3 => 4} of Int32 => Int32
        CRYSTAL
    end

    it "passes for an hash-like literal" do
      expect_no_issues subject, <<-CRYSTAL
        Hash{1 => 2, 3 => 4}
        CRYSTAL
    end

    # Hash literals in macros are semantically different from `Hash(K, V).new`
    it "passes for an empty hash literal in a macro" do
      expect_no_issues subject, <<-CRYSTAL
        macro foo(bar = {} of String => String)
          {% for b, c in bar %}
            {{ b.id }} % {{ c.id }}
          {% end %}

          {% baz = {} of Int32 => Int32 %}
        end

        {% qux = {} of Int32 => Int32 %}
        CRYSTAL
    end

    it "fails for an hash literal without elements" do
      source = expect_issue subject, <<-CRYSTAL
        {} of Int32 => Int32
        # ^^^^^^^^^^^^^^^^^^ error: Use `Hash(Int32, Int32).new` for creating an empty hash
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        Hash(Int32, Int32).new
        CRYSTAL
    end
  end
end
