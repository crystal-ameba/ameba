module Ameba::Rule::Lint
  # A rule that disallows useless assignments.
  #
  # For example, this is considered invalid:
  #
  # ```
  # def method
  #   var = 1
  #   do_something
  # end
  # ```
  #
  # And has to be written as the following:
  #
  # ```
  # def method
  #   var = 1
  #   do_something(var)
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/UselessAssign:
  #   Enabled: true
  # ```
  class UselessAssign < Base
    properties do
      since_version "0.6.0"
      description "Disallows useless variable assignments"
    end

    MSG = "Useless assignment to variable `%s`"

    def test(source)
      UselessAssignScopeVisitor.new self, source
    end

    def test(source, node, scope : AST::Scope)
      return if scope.lib_def?(check_outer_scopes: true)

      scope.variables.each do |var|
        next if var.ignored? || var.used_in_macro? || var.captured_by_block?

        var.assignments.each do |assign|
          check_assignment(source, assign, var)
        end
      end
    end

    private def check_assignment(source, assign, var)
      return if assign.referenced?

      case target_node = assign.target_node
      when Crystal::TypeDeclaration
        issue_for target_node.var, MSG % var.name
      else
        issue_for target_node, MSG % var.name
      end
    end
  end

  private class UselessAssignScopeVisitor < AST::ScopeVisitor
    getter? in_call_args = false

    private def in_call_args(&)
      if in_call_args?
        yield
      else
        @in_call_args = true
        yield
        @in_call_args = false
      end
    end

    def visit(node : Crystal::Call)
      return false unless super

      node.obj.try &.accept(self)
      in_call_args do
        node.args.each &.accept(self)
        node.named_args.try &.each &.accept(self)
      end
      node.block_arg.try &.accept(self)
      node.block.try &.accept(self)

      false
    end

    def visit(node : Crystal::TypeDeclaration)
      super unless in_call_args?
    end

    # Called when finishing processing an assignment to +target+ in +node+.
    # When inside call arguments (+in_call_args?+ is true), the useless
    # assignment checks from the superclass are skipped; otherwise, the
    # superclass implementation is invoked.
    private def on_assign_end(target, node)
      super unless in_call_args?
    end
  end
end
