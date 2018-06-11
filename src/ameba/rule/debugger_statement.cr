module Ameba::Rule
  # A rule that disallows calls to debugger.
  #
  # This is because we don't want debugger breakpoints accidentally being
  # committed into our codebase.
  #
  # YAML configuration example:
  #
  # ```
  # DebuggerStatement:
  #   Enabled: true
  # ```
  #
  struct DebuggerStatement < Base
    properties do
      description "Disallows calls to debugger"
    end

    MSG = "Possible forgotten debugger statement detected"

    def test(source)
      AST::NodeVisitor.new self, source
    end

    def test(source, node : Crystal::Call)
      return unless node.name == "debugger" &&
                    node.args.empty? &&
                    node.obj.nil?

      issue_for node, MSG
    end
  end
end
