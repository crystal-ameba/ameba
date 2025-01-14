module Ameba::Rule::Lint
  # A rule that disallows calls to debugger.
  #
  # This is because we don't want debugger breakpoints accidentally being
  # committed into our codebase.
  #
  # YAML configuration example:
  #
  # ```
  # Lint/DebuggerStatement:
  #   Enabled: true
  # ```
  class DebuggerStatement < Base
    properties do
      since_version "0.1.0"
      description "Disallows calls to debugger"
    end

    MSG = "Possible forgotten debugger statement detected"

    def test(source, node : Crystal::Call)
      return unless node.name == "debugger" &&
                    node.args.empty? &&
                    node.obj.nil?

      issue_for node, MSG
    end
  end
end
