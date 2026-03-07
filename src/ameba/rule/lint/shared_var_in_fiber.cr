module Ameba::Rule::Lint
  # A rule that disallows using shared variables in fibers,
  # which are mutated during iterations.
  #
  # In most cases it leads to unexpected behaviour and is undesired.
  #
  # For example, having this example:
  #
  # ```
  # n = 0
  # channel = Channel(Int32).new
  #
  # while n < 3
  #   n = n + 1
  #   spawn { channel.send n }
  # end
  #
  # 3.times { puts channel.receive } # => # 3, 3, 3
  # ```
  #
  # The problem is there is only one shared between fibers variable `n`
  # and when `channel.receive` is executed its value is `3`.
  #
  # To solve this, the code above needs to be rewritten to the following:
  #
  # ```
  # n = 0
  # channel = Channel(Int32).new
  #
  # while n < 3
  #   n = n + 1
  #   m = n
  #   spawn do { channel.send m }
  # end
  #
  # 3.times { puts channel.receive } # => # 1, 2, 3
  # ```
  #
  # This rule is able to find the shared variables between fibers, which are mutated
  # during iterations. So it reports the issue on the first sample and passes on
  # the second one.
  #
  # There are also other techniques to solve the problem above which are
  # [officially documented](https://crystal-lang.org/reference/guides/concurrency.html)
  #
  # YAML configuration example:
  #
  # ```
  # Lint/SharedVarInFiber:
  #   Enabled: true
  # ```
  class SharedVarInFiber < Base
    include AST::Util

    properties do
      since_version "0.12.0"
      description "Disallows shared variables in fibers"
    end

    MSG = "Shared variable `%s` is used in fiber"

    def test(source)
      AST::ScopeVisitor.new self, source
    end

    def test(source, node, scope : AST::Scope)
      return unless scope.spawn_block?

      scope.references.each do |ref|
        next if (variable = scope.find_variable(ref.name)).nil?
        next if variable.scope == scope || !mutated_in_loop?(variable)

        issue_for ref.node, MSG % variable.name
      end
    end

    # Variable is mutated in loop if it was declared above the loop and assigned inside.
    private def mutated_in_loop?(variable)
      first_assign_node = variable.assignments.first?.try(&.node)

      variable.assignments.any? do |assign|
        next if assign.scope.spawn_block?
        next if assign.node == first_assign_node

        in_loop?(assign.node, variable.scope.node)
      end
    end

    # Returns `true` if *node* is inside a loop within *boundary*.
    private def in_loop?(node, boundary)
      LoopAncestorVisitor.new(node, boundary).in_loop?
    end

    private class LoopAncestorVisitor < Crystal::Visitor
      include AST::Util

      getter? in_loop = false

      def initialize(@target : Crystal::ASTNode, boundary : Crystal::ASTNode)
        boundary.accept(self)
      end

      def visit(node : Crystal::ASTNode)
        return false if @in_loop

        if node.location == @target.location && node.class == @target.class
          @in_loop = @inside_loop
          return false
        end

        true
      end

      def visit(node : Crystal::While | Crystal::Until)
        return false if @in_loop

        prev = @inside_loop
        @inside_loop = true
        node.accept_children(self)
        @inside_loop = prev unless @in_loop
        false
      end

      def visit(node : Crystal::Call)
        return false if @in_loop

        if loop?(node) && (block = node.block)
          prev = @inside_loop
          @inside_loop = true
          block.body.accept(self)
          @inside_loop = prev unless @in_loop
        else
          node.accept_children(self)
        end
        false
      end

      @inside_loop = false
    end
  end
end
