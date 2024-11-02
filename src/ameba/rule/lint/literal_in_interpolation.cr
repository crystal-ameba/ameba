module Ameba::Rule::Lint
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
  # Lint/LiteralInInterpolation
  #   Enabled: true
  # ```
  class LiteralInInterpolation < Base
    include AST::Util

    properties do
      description "Disallows useless string interpolations"
    end

    MSG = "Literal value found in interpolation"

    def test(source, node : Crystal::StringInterpolation)
      each_literal_node(node) { |exp| issue_for exp, MSG }
    end

    private def each_literal_node(node, &)
      node.expressions.each do |exp|
        yield exp if !exp.is_a?(Crystal::StringLiteral) && literal?(exp)
      end
    end
  end
end
