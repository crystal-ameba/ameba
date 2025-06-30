require "../../../spec_helper"

module Ameba::Rule::Style
  describe ArrayLiteralSyntax do
    subject = ArrayLiteralSyntax.new

    it "passes for an array literal with elements" do
      expect_no_issues subject, <<-CRYSTAL
        def print_numbers
          numbers = [1, 2] of Int32
          puts numbers
        end
        CRYSTAL
    end

    it "passes for an array-like literal" do
      expect_no_issues subject, <<-CRYSTAL
        Array{1, 2}
        CRYSTAL
    end

    # Array literals in macros are semantically different from `Array(T).new`
    it "passes for an empty array literal in a macro" do
      expect_no_issues subject, <<-CRYSTAL
        macro foo(bar = [] of String)
          {% for b in bar %}
            {{ b.id }}
          {% end %}

          {% baz = [] of Int32 %}
        end

        {% qux = [] of Int32 %}
        CRYSTAL
    end

    it "fails for an empty array literal" do
      source = expect_issue subject, <<-CRYSTAL
        def print_numbers
          numbers = [] of Int32
                  # ^^^^^^^^^^^ error: Use `Array(Int32).new` for creating an empty array
          numbers << 1
          numbers << 2
          puts numbers
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def print_numbers
          numbers = Array(Int32).new
          numbers << 1
          numbers << 2
          puts numbers
        end
        CRYSTAL
    end
  end
end
