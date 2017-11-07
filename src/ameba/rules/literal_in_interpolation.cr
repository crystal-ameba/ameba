module Ameba::Rules
  # A rule that disallows useless string interpolations
  # that contain a literal value instead of a variable or function.
  #
  # For example:
  #
  # ```
  # "Hello, #{:Ary}"
  # "There are #{4} cats"
  # ```
  #
  struct LiteralInInterpolation < Rule
    include AST::Util

    def test(source)
      AST::Visitor.new self, source
    end

    def test(source, node : Crystal::StringInterpolation)
      found = node.expressions.any? { |e| !string_literal?(e) && literal?(e) }
      return unless found
      source.error self, node.location, "Literal value found in interpolation"
    end
  end
end
