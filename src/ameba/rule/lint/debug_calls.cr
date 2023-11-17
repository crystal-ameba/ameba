module Ameba::Rule::Lint
  # A rule that disallows calls to debug-related methods.
  #
  # This is because we don't want debug calls accidentally being
  # committed into our codebase.
  #
  # YAML configuration example:
  #
  # ```
  # Lint/DebugCalls:
  #   Enabled: true
  #   MethodNames:
  #     - p
  #     - p!
  #     - pp
  #     - pp!
  # ```
  class DebugCalls < Base
    properties do
      description "Disallows debug-related calls"
      method_names %w[p p! pp pp!]
    end

    MSG = "Possibly forgotten debug-related `%s` call detected"

    def test(source, node : Crystal::Call)
      return unless node.name.in?(method_names) && node.obj.nil?

      issue_for node, MSG % node.name
    end
  end
end
