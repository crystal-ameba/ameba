module Ameba::Rule::Lint
  # A rule that disallows string conversion in string interpolation,
  # which is redundant.
  #
  # For example, this is considered invalid:
  #
  # ```
  # "Hello, #{name.to_s}"
  # ```
  #
  # And this is valid:
  #
  # ```
  # "Hello, #{name}"
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/RedundantStringCoercion
  #   Enabled: true
  # ```
  class RedundantStringCoercion < Base
    include AST::Util

    properties do
      description "Disallows redundant string conversions in interpolation"
    end

    MSG = "Redundant use of `Object#to_s` in interpolation"

    def test(source, node : Crystal::StringInterpolation)
      string_coercion_nodes(node).each do |expr|
        issue_for name_location(expr), expr.end_location, MSG
      end
    end

    private def string_coercion_nodes(node)
      node.expressions.select do |exp|
        exp.is_a?(Crystal::Call) &&
          exp.name == "to_s" &&
          exp.args.size.zero? &&
          exp.named_args.nil? &&
          exp.obj
      end
    end
  end
end
