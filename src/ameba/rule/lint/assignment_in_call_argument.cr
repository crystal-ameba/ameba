module Ameba::Rule::Lint
  # A rule that disallows assignments in call arguments.
  #
  # For example, this is considered invalid:
  #
  # ```
  # foo a = 1
  # ```
  #
  # And has to be written as the following:
  #
  # ```
  # a = 1
  #
  # foo a
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/AssignmentInCallArgument:
  #   Enabled: true
  # ```
  class AssignmentInCallArgument < Base
    properties do
      since_version "1.7.0"
      description "Disallows variable assignment in call arguments"
    end

    MSG = "Assignment within a call argument detected"

    def test(source)
      AssignmentInCallArgumentVisitor.new(self, source) do |node|
        issue_for node, MSG
      end
    end
  end

  private class AssignmentInCallArgumentVisitor < AST::ScopeVisitor
    include AST::Util

    getter? in_call_args = false

    def initialize(rule, source, &@on_assign : Crystal::ASTNode ->)
      super(rule, source)
    end

    private def in_call_args(value = true, &)
      prev_value = @in_call_args
      begin
        @in_call_args = value
        yield
      ensure
        @in_call_args = prev_value
      end
    end

    def visit(node : Crystal::Def)
      return super unless node.name == "->"

      in_call_args(false) do
        node.accept_children(self)
      end
      false
    end

    def visit(node : Crystal::Block)
      super

      in_call_args(false) do
        node.accept_children(self)
      end
      false
    end

    def visit(node : Crystal::Call)
      return false if setter_method?(node) || operator_method?(node)
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

    def visit(node : Crystal::Assign | Crystal::OpAssign | Crystal::MultiAssign)
      super.tap do
        @on_assign.call(node) if in_call_args?
      end
    end
  end
end
