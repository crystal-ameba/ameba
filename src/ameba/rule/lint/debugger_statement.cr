module Ameba::Rule::Lint
  # A rule that disallows calls to `debugger`.
  #
  # This is because we don't want debugger breakpoints accidentally
  # committed into our codebase.
  #
  # YAML configuration example:
  #
  # ```
  # Lint/DebuggerStatement:
  #   Enabled: true
  # ```
  class DebuggerStatement < Base
    include AST::Util

    properties do
      since_version "0.1.0"
      description "Disallows calls to `debugger`"
    end

    MSG = "Possibly forgotten `debugger` statement detected"

    def test(source)
      DebuggerStatementVisitor.new(self, source) do |node, statement|
        issue_for(node, MSG) do |corrector|
          corrector.remove(statement)
        end
      end
    end
  end

  private class DebuggerStatementVisitor < AST::BaseVisitor
    include AST::Util

    def initialize(rule, source, &@on_debugger : Crystal::Call, Crystal::ASTNode ->)
      super(rule, source)
    end

    # Removing just the `debugger` call from its suffix form
    # (`debugger if foo`) would leave a dangling condition behind
    def visit(node : Crystal::If | Crystal::Unless)
      return true unless suffix?(node)
      return true unless (call = node.then).is_a?(Crystal::Call)
      return true unless debugger_call?(call)

      @on_debugger.call(call, node)
      node.cond.accept(self)
      false
    end

    def visit(node : Crystal::Call)
      @on_debugger.call(node, node) if debugger_call?(node)
      true
    end

    private def debugger_call?(node)
      node.name == "debugger" && node.obj.nil? && !has_arguments?(node)
    end
  end
end
