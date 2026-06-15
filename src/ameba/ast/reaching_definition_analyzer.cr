module Ameba::AST
  # Performs forward dataflow reaching-definition analysis on a scope's AST,
  # the forward complement of `LivenessAnalyzer`: it answers "which variables
  # already hold a definition that reaches a given program point?".
  #
  # The reaching set is snapshotted at every inner scope node (block, proc,
  # def, ...), following execution order. At conditional joins the branches are
  # merged by union, but a branch that ends in a flow command (`return`,
  # `next`, `break`, `raise`, ...) cannot fall through, so its definitions are
  # excluded from the merge.
  class ReachingDefinitionAnalyzer
    include Util
    include Dataflow

    alias DefinedSet = Set(String)

    @definitions = {} of UInt64 => DefinedSet
    @inner_scope_nodes : Set(UInt64)

    # Creates a new analyzer for *scope*. *entry* is the set of variable names
    # already defined when the scope is entered (its arguments plus any
    # captured outer definitions).
    def initialize(@scope : Scope, @entry : DefinedSet)
      @inner_scope_nodes = @scope.inner_scopes.to_set(&.node.object_id)
    end

    # Returns a mapping of each inner-scope node's `object_id` to the set of
    # variable names that reach the point where that scope is introduced.
    def inner_scope_definitions : Hash(UInt64, DefinedSet)
      if body = scope_body(@scope.node)
        propagate(body, @entry)
      end
      @definitions
    end

    private def propagate(nodes : Enumerable, defined : DefinedSet) : DefinedSet
      nodes.each do |node|
        defined = propagate(node, defined)
      end
      defined
    end

    private def propagate(node : Crystal::Nop?, defined : DefinedSet) : DefinedSet
      defined
    end

    private def propagate(node : Crystal::ASTNode, defined : DefinedSet) : DefinedSet
      if @inner_scope_nodes.includes?(node.object_id)
        @definitions[node.object_id] = defined.dup
        return defined
      end
      transfer(node, defined)
    end

    private def transfer(node : Crystal::Expressions, defined : DefinedSet) : DefinedSet
      propagate(node.expressions, defined)
    end

    private def transfer(node : Crystal::Assign | Crystal::OpAssign, defined : DefinedSet) : DefinedSet
      defined = propagate(node.value, defined)
      define(node.target, defined)
    end

    private def transfer(node : Crystal::MultiAssign, defined : DefinedSet) : DefinedSet
      defined = propagate(node.values, defined)
      node.targets.each do |target|
        defined = define(target, defined)
      end
      defined
    end

    private def transfer(node : Crystal::UninitializedVar, defined : DefinedSet) : DefinedSet
      define(node.var, defined)
    end

    private def transfer(node : Crystal::TypeDeclaration, defined : DefinedSet) : DefinedSet
      defined = propagate(node.value, defined)
      define(node.var, defined)
    end

    private def transfer(node : Crystal::Call, defined : DefinedSet) : DefinedSet
      defined = propagate(node.obj, defined)
      defined = propagate(node.args, defined)
      defined = propagate(node.named_args, defined)
      defined = propagate(node.block_arg, defined)
      defined = propagate(node.block, defined)
      defined
    end

    private def transfer(node : Crystal::BinaryOp, defined : DefinedSet) : DefinedSet
      defined = propagate(node.left, defined)
      propagate(node.right, defined)
    end

    {% for type in BRANCH_NODES %}
      private def transfer(node : Crystal::{{ type.id }}, defined : DefinedSet) : DefinedSet
        defined = propagate(node.cond, defined)
        merge_branches(defined, {node.then, node.else})
      end
    {% end %}

    {% for type in LOOP_NODES %}
      # A loop body is walked once in textual order: a variable assigned later
      # in the body is not in scope at an earlier point, since Crystal scoping
      # is lexical and does not extend a definition backwards over the back edge.
      private def transfer(node : Crystal::{{ type.id }}, defined : DefinedSet) : DefinedSet
        defined = propagate(node.cond, defined)
        defined | propagate(node.body, defined)
      end
    {% end %}

    {% for type in CASE_NODES %}
      private def transfer(node : Crystal::{{ type.id }}, defined : DefinedSet) : DefinedSet
        merge_case(node, defined)
      end
    {% end %}

    private def transfer(node : Crystal::ExceptionHandler, defined : DefinedSet) : DefinedSet
      body_defined = propagate(node.body, defined)

      merged = nil
      if else_node = node.else
        else_defined = propagate(else_node, body_defined)
        merged = collect(merged, else_defined) unless terminates?(else_node)
      else
        merged = collect(merged, body_defined)
      end

      rescue_entry = defined | body_defined
      node.rescues.try &.each do |rescue_node|
        rescue_defined = propagate(rescue_node.body, rescue_entry)
        merged = collect(merged, rescue_defined) unless terminates?(rescue_node.body)
      end

      merged ||= body_defined
      propagate(node.ensure, merged)
    end

    {% for type in INNER_SCOPE_NODES %}
      private def transfer(node : Crystal::{{ type.id }}, defined : DefinedSet) : DefinedSet
        defined
      end
    {% end %}

    private def transfer(node : Crystal::ASTNode, defined : DefinedSet) : DefinedSet
      children = [] of Crystal::ASTNode
      node.accept_children(ChildCollector.new(children))

      propagate(children, defined)
    end

    private def define(target : Crystal::Var, defined : DefinedSet) : DefinedSet
      return defined if target.name.in?(defined)
      defined.dup << target.name
    end

    private def define(target : Crystal::Splat, defined : DefinedSet) : DefinedSet
      define(target.exp, defined)
    end

    private def define(target, defined : DefinedSet) : DefinedSet
      defined
    end

    private def merge_branches(base : DefinedSet, branches) : DefinedSet
      merged = nil
      branches.each do |branch|
        branch_defined = propagate(branch, base)
        merged = collect(merged, branch_defined) unless terminates?(branch)
      end
      merged || base
    end

    private def merge_case(node : Crystal::Case | Crystal::Select, defined : DefinedSet) : DefinedSet
      base = defined
      if node.is_a?(Crystal::Case) && (cond = node.cond)
        base = propagate(cond, base)
      end

      merged = nil
      node.whens.each do |when_node|
        when_defined = propagate(when_node.conds, base)
        when_defined = propagate(when_node.body, when_defined)
        merged = collect(merged, when_defined) unless terminates?(when_node.body)
      end

      if else_node = node.else
        else_defined = propagate(else_node, base)
        merged = collect(merged, else_defined) unless terminates?(else_node)
      else
        merged = collect(merged, base)
      end

      merged || base
    end

    private def collect(merged : DefinedSet?, defined : DefinedSet) : DefinedSet
      merged ? merged | defined : defined.dup
    end

    private def terminates?(node) : Bool
      flow_expression?(node, in_loop: true)
    end
  end
end
