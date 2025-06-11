module Ameba::Rule::Lint
  # This rule is used to identify comparisons between two literals.
  #
  # They usually have the same result - except for non-primitive
  # types like containers, range or regex.
  #
  # For example, this will be always false:
  #
  # ```
  # "foo" == 42
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/LiteralsComparison:
  #   Enabled: true
  # ```
  class LiteralsComparison < Base
    include AST::Util

    properties do
      since_version "1.3.0"
      description "Identifies comparisons between literals"
    end

    OP_NAMES = %w[=== == !=]

    MSG = "Comparison always evaluates to %s"

    def test(source, node : Crystal::Call)
      return unless node.name.in?(OP_NAMES)
      return unless (obj = node.obj) && (arg = node.args.first?)

      return unless static_literal?(obj)
      return unless static_literal?(arg)

      is_equal = obj.to_s == arg.to_s

      what =
        case node.name
        when "==", "!="
          "`#{is_equal}`"
        else
          "the same"
        end

      issue_for node, MSG % what
    end
  end
end
