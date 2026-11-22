module Ameba::Rule::Lint
  # A rule that disallows `rand(0)` and `rand(1)` calls.
  # `rand(1)` always returns `0`, while `rand(0)` and `rand(0.0)` raise
  # an `ArgumentError`.
  #
  # For example:
  #
  # ```
  # rand(1)
  # ```
  #
  # Should be written as:
  #
  # ```
  # rand
  # # or
  # rand(2)
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/RandZero:
  #   Enabled: true
  # ```
  class RandZero < Base
    properties do
      since_version "0.5.1"
      description "Disallows `rand` zero calls"
    end

    MSG      = "`%s` always returns `0`"
    MSG_ZERO = "`%s` raises an `ArgumentError` due to an invalid bound"

    def test(source, node : Crystal::Call)
      return unless node.name == "rand" &&
                    node.args.size == 1 &&
                    (arg = node.args.first).is_a?(Crystal::NumberLiteral)

      case arg.value.to_f?
      when 0
        issue_for(node, MSG_ZERO % node)
      when 1
        # `rand(1.0)` returns a random float in the `[0, 1)` range
        issue_for(node, MSG % node) unless arg.kind.float?
      end
    end
  end
end
