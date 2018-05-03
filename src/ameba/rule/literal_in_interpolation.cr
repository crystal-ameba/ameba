module Ameba::Rule
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
  # YAML configuration example:
  #
  # ```
  # LiteralInInterpolation
  #   Enabled: true
  # ```
  #
  struct LiteralInInterpolation < Base
    include AST::Util

    properties do
      description "Disallows useless string interpolations"
    end

    MSG = "Literal value found in interpolation"

    def test(source)
      AST::NodeVisitor.new self, source
    end

    def test(source, node : Crystal::StringInterpolation)
      found = node.expressions.any? { |e| !string_literal?(e) && literal?(e) }
      return unless found
      source.error self, node.location, MSG
    end
  end
end
