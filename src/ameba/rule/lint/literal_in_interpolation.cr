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
  # Lint/LiteralInInterpolation:
  #   Enabled: true
  # ```
  class LiteralInInterpolation < Base
    include AST::Util

    properties do
      since_version "0.1.0"
      description "Disallows useless string interpolations"
    end

    MSG = "Literal value found in interpolation"

    MAGIC_CONSTANTS = %w[__LINE__ __FILE__ __DIR__]

    def test(source, node : Crystal::StringInterpolation)
      each_literal_node(source, node) { |exp| issue_for exp, MSG }
    end

    private def each_literal_node(source, node, &)
      source_lines = source.lines

      node.expressions.each do |exp|
        next if exp.is_a?(Crystal::StringLiteral)
        next unless static_literal?(exp)
        next unless code = node_source(exp, source_lines)
        next if code.in?(MAGIC_CONSTANTS)

        yield exp
      end
    end
  end
end
