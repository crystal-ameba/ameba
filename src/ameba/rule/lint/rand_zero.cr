module Ameba::Rule::Lint
  # A rule that disallows `rand(1)` calls, along with calls with a zero
  # or negative bound, like `rand(0)` or `rand(-1)`.
  # `rand(1)` always returns `0`, while the latter raise an `ArgumentError`.
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

    MSG               = "`%s` always returns `0`"
    MSG_INVALID_BOUND = "`%s` raises an `ArgumentError` due to an invalid bound"

    def test(source, node : Crystal::Call)
      return unless node.name == "rand" &&
                    node.args.size == 1 &&
                    (arg = node.args.first).is_a?(Crystal::NumberLiteral)

      return unless value = arg.value.to_f?

      case value
      when .<=(0)
        issue_for(node, MSG_INVALID_BOUND % node)
      when 1
        # `rand(1.0)` returns a random float in the `[0, 1)` range
        issue_for(node, MSG % node) unless arg.kind.float?
      end
    end
  end
end
