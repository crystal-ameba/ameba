module Ameba::Rule::Style
  # A rule that disallows the use of `while true` (or `until false`)
  # instead of using the idiomatic `loop`
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
  # The same applies to `until false`:
  #
  # ```
  # until false
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
      description "Disallows `while true` and `until false` statements"
    end

    MSG       = "While statement using `true` literal as condition"
    MSG_UNTIL = "Until statement using `false` literal as condition"

    def test(source)
      AST::ScopeVisitor.new(self, source)
    end

    def test(source, node, scope : AST::Scope)
      WhileTrueCollector.new(scope).nodes.each do |loop_node|
        case loop_node
        when Crystal::While, Crystal::Until
          report(source, loop_node, scope)
        end
      end
    end

    private def report(source, node : Crystal::While | Crystal::Until, scope)
      return unless location = node.location
      return unless end_location = node.cond.end_location

      msg = node.is_a?(Crystal::Until) ? MSG_UNTIL : MSG

      if declares_variables_used_after?(node, scope)
        issue_for(node, msg)
      else
        issue_for(node, msg) do |corrector|
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
    getter nodes = [] of Crystal::While | Crystal::Until

    @inner_scope_nodes : Set(UInt64)

    def initialize(scope : AST::Scope)
      @inner_scope_nodes = scope.inner_scopes.map(&.node.object_id).to_set
      scope.node.accept(self)
    end

    def visit(node : Crystal::While | Crystal::Until)
      @nodes << node if AST::Util.endless_loop_condition?(node)
      true
    end

    def visit(node : Crystal::ASTNode)
      !node.object_id.in?(@inner_scope_nodes)
    end
  end
end
