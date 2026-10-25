module Ameba::Rule::Style
  # A rule that disallows the use of `while true` instead of using the idiomatic `loop`
  #
  # For example, this is considered invalid:
  #
  # ```
  # while true
  #   do_something
  #   break if some_condition
  # end
  # ```
  #
  # And should be replaced by the following:
  #
  # ```
  # loop do
  #   do_something
  #   break if some_condition
  # end
  # ```
  #
  # NOTE: The issues are not autocorrected if there are any variables declared
  # within the `while` loop and referenced after it, since these become local
  # to the `loop` block, and thus inaccessible after it.
  #
  # YAML configuration example:
  #
  # ```
  # Style/WhileTrue:
  #   Enabled: true
  # ```
  class WhileTrue < Base
    properties do
      since_version "0.3.0"
      description "Disallows `while` statements with a `true` literal as condition"
    end

    MSG = "While statement using `true` literal as condition"

    def test(source)
      AST::ScopeVisitor.new(self, source)
    end

    def test(source, node, scope : AST::Scope)
      WhileTrueCollector.new(scope).nodes.each do |while_node|
        report(source, while_node, scope)
      end
    end

    private def report(source, node, scope)
      return unless location = node.location
      return unless end_location = node.cond.end_location

      if declares_variables_used_after?(node, scope)
        issue_for(node, MSG)
      else
        issue_for(node, MSG) do |corrector|
          corrector.replace(location, end_location, "loop do")
        end
      end
    end

    # Returns `true` if any of the *scope* variables is declared (first assigned)
    # within the `while` *node*, and referenced after it.
    private def declares_variables_used_after?(node, scope)
      return true unless (location = node.location) && (end_location = node.end_location)

      scope.variables.any? do |var|
        next false unless assign_location = var.assignments.first?.try(&.location)
        next false unless location <= assign_location <= end_location

        var.references.any? do |ref|
          !(ref_location = ref.location) || ref_location > end_location
        end
      end
    end
  end

  # Collects the `while true` nodes within the scope, excluding its inner scopes.
  private class WhileTrueCollector < Crystal::Visitor
    getter nodes = [] of Crystal::While

    @inner_scope_nodes : Set(UInt64)

    def initialize(scope : AST::Scope)
      @inner_scope_nodes = scope.inner_scopes.map(&.node.object_id).to_set
      scope.node.accept(self)
    end

    def visit(node : Crystal::While)
      @nodes << node if node.cond.true_literal?
      true
    end

    def visit(node : Crystal::ASTNode)
      !node.object_id.in?(@inner_scope_nodes)
    end
  end
end
