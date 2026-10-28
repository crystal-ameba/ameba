module Ameba::Rule::Lint
  # A rule that disallows comparison to booleans.
  #
  # For example, these are considered invalid:
  #
  # ```
  # foo == true
  # bar != false
  # false === baz
  # ```
  #
  # This is because these expressions evaluate to `true` or `false`, so you
  # could get the same result by using either the variable directly,
  # or negating the variable.
  #
  # NOTE: The issues are not autocorrected, since the results are the same
  # only for the `Bool` values, while i.e. `1 == true` is `false`, and `1`
  # alone is truthy.
  #
  # YAML configuration example:
  #
  # ```
  # Lint/ComparisonToBoolean:
  #   Enabled: true
  # ```
  class ComparisonToBoolean < Base
    properties do
      since_version "0.1.0"
      enabled false
      description "Disallows comparison to booleans"
    end

    MSG      = "Comparison to a boolean is pointless"
    OP_NAMES = %w[== != ===]

    def test(source, node : Crystal::Call)
      return unless node.name.in?(OP_NAMES)
      return unless node.args.size == 1

      arg, obj = node.args.first, node.obj
      case
      when arg.is_a?(Crystal::BoolLiteral)
        bool, exp = arg, obj
      when obj.is_a?(Crystal::BoolLiteral)
        bool, exp = obj, arg
      end

      return unless bool && exp

      issue_for(node, MSG)
    end
  end
end
