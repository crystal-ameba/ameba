module Ameba::Rules
  # A rule that disallows useless string interpolations
  # that contain a literal value instead of a variable or function.
  #
  # For example:
  #
  # ```
  # "Hello, #{:Ary}"
  # "The are #{4} cats"
  # ```
  #
  struct LiteralInInterpolation < Rule
    include AST::Util

    def test(source)
      AST::StringInterpolationVisitor.new self, source
    end

    def test(source, node : Crystal::StringInterpolation)
      has_literal = node.expressions.any? do |e|
        !string_literal?(e) && literal?(e)
      end

      return unless has_literal

      source.error self, node.location.try &.line_number,
        "Literal value found in interpolation"
    end
  end
end
