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
  # YAML configuration example:
  #
  # ```
  # Lint/ComparisonToBoolean:
  #   Enabled: true
  # ```
  class ComparisonToBoolean < Base
    include AST::Util

    properties do
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
      return unless exp_code = node_source(exp, source.lines)

      not =
        case node.name
        when "==", "===" then !bool.value # foo == false
        when "!="        then bool.value  # foo != true
        end

      exp_code = "!#{exp_code}" if not

      issue_for node, MSG do |corrector|
        corrector.replace(node, exp_code)
      end
    end
  end
end
