module Ameba::Rule
  # A rule that disallows calls to debugger.
  #
  # This is because we don't want debugger breakpoints accidentally being
  # committed into our codebase.
  #
  struct DebuggerStatement < Base
    def test(source)
      AST::Visitor.new self, source
    end

    def test(source, node : Crystal::Call)
      return unless node.name == "debugger" &&
                    node.args.empty? &&
                    node.obj.nil?

      source.error self, node.location,
        "Possible forgotten debugger statement detected"
    end
  end
end
