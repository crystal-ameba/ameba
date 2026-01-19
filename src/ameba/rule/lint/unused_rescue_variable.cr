module Ameba::Rule::Lint
  # A rule that disallows unused `rescue` variables.
  #
  # For example, this is considered invalid:
  #
  # ```
  # begin
  #   raise MyException.new("OH NO!")
  # rescue ex : MyException
  #   puts "Rescued MyException"
  # end
  # ```
  #
  # and should be written as:
  #
  # ```
  # begin
  #   raise MyException.new("OH NO!")
  # rescue MyException
  #   puts "Rescued MyException"
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/UnusedRescueVariable:
  #   Enabled: true
  # ```
  class UnusedRescueVariable < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Disallows unused `rescue` variables"
    end

    MSG = "Unused `rescue` variable `%s`"

    def test(source, node : Crystal::Rescue)
      return unless name = node.name

      visitor = VariableReferenceVisitor.new(node.body, name)
      return if visitor.referenced?

      issue_for name_location_or(node, adjust_location_column_number: {{ "rescue ".size }}),
        MSG % name
    end
  end

  private class VariableReferenceVisitor < Crystal::Visitor
    getter variable_name : String
    getter? referenced = false

    def initialize(node : Crystal::ASTNode, @variable_name)
      node.accept(self)
    end

    def visit(node : Crystal::Var)
      @referenced = true if node.name == variable_name
      true
    end

    # Shadowed variable usage check
    def visit(node : Crystal::Block)
      node.args.all? { |arg| should_visit?(arg) }
    end

    # Shadowed variable usage check
    def visit(node : Crystal::ProcLiteral)
      node.def.args.all? { |arg| should_visit?(arg) }
    end

    # Shadowed variable usage check
    def visit(node : Crystal::UninitializedVar)
      should_visit?(node.var)
    end

    # Shadowed variable usage check
    def visit(node : Crystal::Assign | Crystal::OpAssign)
      should_visit?(node.target)
    end

    # Shadowed variable usage check
    def visit(node : Crystal::MultiAssign)
      node.targets.all? { |target| should_visit?(target) }
    end

    def visit(node : Crystal::ASTNode)
      true
    end

    private def should_visit?(node : Crystal::Var | Crystal::Arg)
      node.name != variable_name
    end

    private def should_visit?(node : Crystal::ASTNode)
      true
    end
  end
end
