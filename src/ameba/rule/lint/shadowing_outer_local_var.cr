module Ameba::Rule::Lint
  # A rule that disallows the usage of the same name as outer local variables
  # for block or proc arguments.
  #
  # For example, this is considered incorrect:
  #
  # ```
  # def some_method
  #   foo = 1
  #
  #   3.times do |foo| # shadowing outer `foo`
  #   end
  # end
  # ```
  #
  # and should be written as:
  #
  # ```
  # def some_method
  #   foo = 1
  #
  #   3.times do |bar|
  #   end
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/ShadowingOuterLocalVar:
  #   Enabled: true
  # ```
  class ShadowingOuterLocalVar < Base
    properties do
      since_version "0.7.0"
      description "Disallows the usage of the same name as outer local variables " \
                  "for block or proc arguments"
    end

    MSG = "Shadowing outer local variable `%s`"

    def test(source)
      AST::ScopeVisitor.new self, source, skip: [
        Crystal::Macro,
        Crystal::MacroFor,
      ]
    end

    def test(source, node : Crystal::ProcLiteral | Crystal::Block, scope : AST::Scope)
      find_shadowing source, scope
    end

    private def find_shadowing(source, scope)
      return unless outer_scope = scope.outer_scope

      branch_visitors = {} of UInt64 => BranchPathVisitor

      each_argument_node(scope) do |arg|
        # TODO: handle unpacked variables from `Block#unpacks`
        next unless name = arg.name.presence

        variable = outer_scope.find_variable(name)

        next if variable.nil? || !variable.declared_before?(arg)
        next if outer_scope.assigns_ivar?(name)
        next if outer_scope.assigns_type_dec?(name)
        next if mutually_exclusive_branches?(branch_visitors, variable, arg)

        issue_for arg.node, MSG % name, prefer_name_location: true
      end
    end

    private def mutually_exclusive_branches?(visitors, variable, arg)
      return false if variable.assignments.empty?

      scope_node = variable.scope.node
      visitor = visitors[scope_node.object_id] ||= BranchPathVisitor.new.tap do |v|
        scope_node.accept(v)
      end

      arg_path = visitor.paths[arg.node.object_id]
      variable.assignments.all? do |assignment|
        diverges?(arg_path, visitor.paths[assignment.node.object_id])
      end
    end

    private def diverges?(path1, path2)
      shared_depth = {path1.size, path2.size}.min

      shared_depth.times do |i|
        ancestor1, branch1 = path1[i]
        ancestor2, branch2 = path2[i]

        return false unless ancestor1.same?(ancestor2)
        return true unless branch1 == branch2
      end

      false
    end

    private def each_argument_node(scope, &)
      scope.arguments.each do |arg|
        yield arg unless arg.ignored?
      end
    end

    private class BranchPathVisitor < Crystal::Visitor
      alias Segment = Tuple(Crystal::ASTNode, Symbol | Int32)
      alias Path = Array(Segment)

      getter paths = {} of UInt64 => Path

      def initialize
        @stack = Path.new
      end

      def visit(node : Crystal::ASTNode)
        record(node)
        true
      end

      def visit(node : Crystal::If | Crystal::Unless)
        visit_conditional(node, node.cond, node.then, node.else)
      end

      def visit(node : Crystal::Case)
        record(node)
        node.cond.try &.accept(self)
        visit_when_branches(node, node.whens, node.else)
      end

      def visit(node : Crystal::Select)
        record(node)
        visit_when_branches(node, node.whens, node.else)
      end

      def visit(node : Crystal::ExceptionHandler)
        record(node)
        node.body.accept(self)
        node.rescues.try &.each_with_index do |rescue_node, index|
          enter(node, index) { rescue_node.body.accept(self) }
        end
        if else_node = node.else
          enter(node, :else) { else_node.accept(self) }
        end
        node.ensure.try &.accept(self)
        false
      end

      private def visit_conditional(node, cond, then_branch, else_branch)
        record(node)
        cond.accept(self)
        enter(node, :then) { then_branch.accept(self) }
        enter(node, :else) { else_branch.accept(self) }
        false
      end

      private def visit_when_branches(node, whens, else_node)
        whens.each_with_index do |when_node, index|
          when_node.conds.each &.accept(self)
          enter(node, index) { when_node.body.accept(self) }
        end
        if else_node
          enter(node, :else) { else_node.accept(self) }
        end
        false
      end

      private def enter(node, branch_id, &)
        @stack.push({node, branch_id})
        yield
        @stack.pop
      end

      private def record(node)
        paths[node.object_id] = @stack.dup
      end
    end
  end
end
