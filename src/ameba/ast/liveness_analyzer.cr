module Ameba::AST
  # Performs backward dataflow liveness analysis on a scope's AST to detect
  # dead stores (assignments whose values are never read before being
  # overwritten or the scope ends).
  #
  # The algorithm walks the AST in reverse execution order, maintaining a
  # set of variable names that are currently "live" (will be read in the
  # future). When an assignment is encountered and its target variable is
  # not in the live set, the assignment is marked as a dead store.
  class LivenessAnalyzer
    include Dataflow
    include Util

    alias LiveSet = Set(String)

    record Result,
      dead_stores : Array(Assignment),
      entry_live_set : LiveSet

    # Live sets for flow control: `break` exits to post-loop,
    # `next` jumps to loop condition, `return` exits the scope, and a raised
    # exception jumps to the enclosing `rescue` clauses (or exits the scope),
    # all of them through the enclosing `ensure` clauses. Without these,
    # assignments before break/next/return/raise would be incorrectly marked as dead.
    private record FlowControl,
      break_live : LiveSet,
      next_live : LiveSet,
      return_live : LiveSet,
      raise_live : LiveSet

    private struct FlowControl
      # Returns the flow control with each of the live sets passed through the block.
      def map(& : LiveSet -> LiveSet) : FlowControl
        FlowControl.new(
          yield(break_live),
          yield(next_live),
          yield(return_live),
          yield(raise_live),
        )
      end

      # Returns the variables live on any of the jumps.
      def live : LiveSet
        break_live | next_live | return_live | raise_live
      end
    end

    # Maximum iterations for fixed-point convergence in loops.
    # In practice, convergence happens in 2-3 iterations since the live set
    # can only grow monotonically and is bounded by the number of variables.
    private MAX_FIXED_POINT_ITERATIONS = 100

    @dead_stores = [] of Assignment
    @var_names : Set(String)
    @assignment_map : Hash(Tuple(String, UInt64), Assignment)
    @inner_scope_nodes : Set(UInt64)
    @inner_scope_reads : Hash(UInt64, LiveSet)

    @flow : FlowControl

    # Variables live when leaving the scope, i.e. the captured variables,
    # which might be read after the closure returns, or on its next invocation.
    @exit_live : LiveSet

    # Creates a new analyzer of the *scope*'s variables, and additionally
    # the *captured_variables* (i.e. the outer scope variables assigned
    # within a block), which are analyzed as long as they're assigned within
    # the *scope*, and the *shadowed_variables* (i.e. the outer scope variables
    # assigned within a type definition, which doesn't see them), which are
    # analyzed as the *scope*'s own variables.
    def initialize(@scope : Scope, captured_variables = [] of Variable, shadowed_variables = [] of Variable)
      variables = @scope.variables + captured_variables + shadowed_variables

      @var_names = variables.to_set(&.name)
      @exit_live = captured_variables
        .select { |var| var.referenced? || var.used_in_macro? }
        .to_set(&.name)
      @flow = FlowControl.new(@exit_live, @exit_live, @exit_live, @exit_live)
      @assignment_map = build_assignment_map(variables)
      @inner_scope_nodes = @scope.inner_scopes.to_set(&.node.object_id)
      @inner_scope_reads = build_inner_scope_reads(variables)
    end

    # Returns assignments where the value is never read before being
    # overwritten or the scope ends.
    def dead_stores : Array(Assignment)
      analyze.dead_stores
    end

    # Returns the set of variable names that are live at scope entry.
    # A variable live at entry means its value (e.g. from a method argument)
    # will be read before being overwritten.
    def entry_live_set : LiveSet
      analyze.entry_live_set
    end

    # Performs liveness analysis in a single pass, returning both the dead
    # stores and the entry live set.
    def analyze : Result
      @dead_stores.clear

      body = scope_body(@scope.node)
      entry_live = propagate_through(body, @exit_live)

      Result.new(@dead_stores, entry_live)
    end

    private def build_assignment_map(variables)
      map = Hash(Tuple(String, UInt64), Assignment).new

      variables.each do |var|
        var.assignments.each do |assign|
          key = {var.name, assign.node.object_id}
          map[key] ||= assign
        end
      end
      map
    end

    # Maps the nodes of the inner scopes to the names of this scope's variables
    # referenced within them (at any depth), i.e. `a` for the block in
    # `a = 1; [1].each { puts a }`, including the references within macros,
    # i.e. `a` for the macro in `a = 1; {% if flag?(:foo) %} puts a {% end %}`.
    private def build_inner_scope_reads(variables)
      reads = Hash(UInt64, LiveSet).new

      variables.each do |var|
        var.references.each do |ref|
          next unless inner_scope = inner_scope_containing(ref.scope)

          reads.put_if_absent(inner_scope.node.object_id) { LiveSet.new } << var.name
        end
      end

      @scope.inner_scopes.each do |inner_scope|
        next if (names = macro_reads(inner_scope.node)).empty?

        reads.put_if_absent(inner_scope.node.object_id) { LiveSet.new }.concat(names)
      end
      reads
    end

    # Returns the names of the variables referenced within the macros of the *node*.
    private def macro_reads(node) : LiveSet
      @var_names.select do |name|
        MacroReferenceFinder.new(node, name).references?
      end.to_set
    end

    # Returns the inner scope of the analyzed scope, which contains (or is)
    # the given *scope*, or `nil` if there's no such scope.
    private def inner_scope_containing(scope) : Scope?
      while scope && (outer_scope = scope.outer_scope)
        return scope if outer_scope.same?(@scope)
        scope = outer_scope
      end
    end

    private def inner_scope_node?(node)
      @inner_scope_nodes.includes?(node.object_id)
    end

    # Returns the name of the analyzed variable assigned by the *target* node,
    # or `nil` if it's not a variable (i.e. `obj.foo` or `@foo`), or not analyzed.
    private def tracked_var_name(target) : String?
      if (var = assigned_var(target)) && var.name.in?(@var_names)
        var.name
      end
    end

    private def find_assignment(node, var_name) : Assignment?
      @assignment_map[{var_name, node.object_id}]?
    end

    # Records a dead store if the variable is not in the live set.
    private def mark_dead_store(assign_node, var_name, live : LiveSet) : Nil
      return if var_name.in?(live)

      if assign = find_assignment(assign_node, var_name)
        @dead_stores << assign
      end
    end

    # Adds `var_name` to the live set.
    private def add_to_live_set(var_name, live : LiveSet) : LiveSet
      return live if var_name.in?(live)

      live = live.dup
      live.add(var_name)
      live
    end

    # Removes `var_name` from the live set. When `mark` is true,
    # records a dead store if the variable was not live at this point.
    private def remove_from_live_set(assign_node, var_name, live : LiveSet, mark) : LiveSet
      mark_dead_store(assign_node, var_name, live) if mark

      if live.includes?(var_name)
        live = live.dup
        live.delete(var_name)
      end
      live
    end

    # Type-specific overloads. Crystal dispatches to the most specific matching
    # overload at runtime when the argument is a virtual type (Crystal::ASTNode+).

    private def propagate_through(nodes : Enumerable, live : LiveSet, mark = true) : LiveSet
      nodes.reverse_each do |node|
        live = propagate_through(node, live, mark)
      end
      live
    end

    private def propagate_through(node : Crystal::Nop?, live : LiveSet, mark = true) : LiveSet
      live
    end

    private def propagate_through(node : Crystal::Expressions, live : LiveSet, mark = true) : LiveSet
      propagate_through(node.expressions, live, mark)
    end

    private def propagate_through(node : Crystal::NamedArgument, live : LiveSet, mark = true) : LiveSet
      propagate_through(node.value, live, mark)
    end

    private def propagate_through(node : Crystal::Assign, live : LiveSet, mark = true) : LiveSet
      return live if inner_scope_node?(node)

      target = node.target
      unless name = tracked_var_name(target)
        live = propagate_through(node.value, live, mark)
        return propagate_through(target, live, mark)
      end

      # Only remove from live set if this assignment is tracked in the scope.
      # Untracked assignments (e.g. inside record/accessor macro args) are transparent.
      if find_assignment(node, name)
        live = remove_from_live_set(node, name, live, mark)
      end
      propagate_through(node.value, live, mark)
    end

    private def propagate_through(node : Crystal::OpAssign, live : LiveSet, mark = true) : LiveSet
      return live if inner_scope_node?(node)

      # The operator (unless a logical one) is a call, which might raise
      raising = !node.op.in?("||", "&&")

      target = node.target
      unless name = tracked_var_name(target)
        live = propagate_through(node.value, live, mark)
        live = propagate_through_raise(live) if raising
        return propagate_through(target, live, mark)
      end

      # OpAssign both writes and reads the variable (x += 1 means x = x + 1).
      # Mark the dead store if the result is never read, then ensure the
      # variable is live (since the op-assign reads the current value).
      mark_dead_store(node, name, live) if mark
      live = add_to_live_set(name, live)
      live = propagate_through_raise(live) if raising
      propagate_through(node.value, live, mark)
    end

    private def propagate_through(node : Crystal::MultiAssign, live : LiveSet, mark = true) : LiveSet
      # A single value gets indexed for each of the targets in turn,
      # which might raise both before and in between the assignments
      raising = node.values.size == 1

      live = propagate_through_raise(live) if raising
      node.targets.reverse_each do |target|
        if name = tracked_var_name(target)
          live = remove_from_live_set(node, name, live, mark)
        else
          # Other targets (i.e. `obj.foo` or `arr[i]`) read their receivers and arguments
          live = propagate_through(target, live, mark)
        end
      end
      live = propagate_through_raise(live) if raising
      propagate_through(node.values, live, mark)
    end

    private def propagate_through(node : Crystal::UninitializedVar, live : LiveSet, mark = true) : LiveSet
      if name = tracked_var_name(node.var)
        live = remove_from_live_set(node, name, live, mark)
      end
      live
    end

    private def propagate_through(node : Crystal::Out, live : LiveSet, mark = true) : LiveSet
      # `out x` assigns the variable (rather than reading it), yet its value
      # is often unwanted, being required only by the C function signature,
      # so don't mark it as dead.
      if (name = tracked_var_name(node.exp)) && find_assignment(node, name)
        live = remove_from_live_set(node, name, live, mark: false)
      end
      live
    end

    private def propagate_through(node : Crystal::TypeDeclaration, live : LiveSet, mark = true) : LiveSet
      if name = tracked_var_name(node.var)
        # Type declarations without a value are type restrictions, not
        # assignments — don't mark as dead. Since Crystal requires the
        # variable to be previously undefined, kill it from the live set
        # as no prior references can exist.
        live = remove_from_live_set(node, name, live, mark && !node.value.nil?)
      end
      propagate_through(node.value, live, mark)
    end

    private def propagate_through(node : Crystal::Var, live : LiveSet, mark = true) : LiveSet
      return live unless node.name.in?(@var_names)

      add_to_live_set(node.name, live)
    end

    {% for type in BRANCH_NODES %}
      private def propagate_through(node : Crystal::{{ type.id }}, live : LiveSet, mark = true) : LiveSet
        then_live = propagate_through(node.then, live, mark)
        else_live = propagate_through(node.else, live, mark)

        propagate_through(node.cond, then_live | else_live, mark)
      end
    {% end %}

    {% for type in LOOP_NODES %}
      private def propagate_through(node : Crystal::{{ type.id }}, live : LiveSet, mark = true) : LiveSet
        propagate_through_loop(node, live, mark)
      end
    {% end %}

    private def propagate_through(node : Crystal::Case, live : LiveSet, mark = true) : LiveSet
      # Each `when` conditions are evaluated only if the preceding ones
      # didn't match, so the branches are chained as `if`/`elsif`/`else`.
      branch_live = propagate_through_else(node, live, mark)

      node.whens.reverse_each do |when_node|
        when_live = propagate_through(when_node.body, live, mark)
        branch_live = propagate_through(when_node.conds, when_live | branch_live, mark)
      end

      propagate_through(node.cond, branch_live, mark)
    end

    private def propagate_through(node : Crystal::Select, live : LiveSet, mark = true) : LiveSet
      # Only the `when` condition of the chosen branch completes,
      # so the branches are alternatives to each other.
      branch_live = propagate_through_else(node, live, mark)

      node.whens.each do |when_node|
        when_live = propagate_through(when_node.body, live, mark)
        branch_live |= propagate_through(when_node.conds, when_live, mark)
      end
      branch_live
    end

    # Returns the variables live on entering the `else` branch of the *node*,
    # or on falling through it (without any of the branches executed).
    private def propagate_through_else(node : Crystal::Case | Crystal::Select, live : LiveSet, mark) : LiveSet
      if else_node = node.else
        return propagate_through(else_node, live, mark)
      end

      # `select` without `else` blocks until one of its branches gets executed,
      # exhaustive `case ... in` covers all of the possible values
      node.is_a?(Crystal::Select) || node.exhaustive? ? LiveSet.new : live
    end

    private def propagate_through(node : Crystal::ExceptionHandler, live : LiveSet, mark = true) : LiveSet
      # The `ensure` clause is entered on every way out of the handler,
      # so its assignments are dead stores only if dead on each of these.
      if mark && (ensure_node = node.ensure)
        propagate_through(ensure_node, live | @flow.live, mark)
      end
      post_ensure = propagate_through(node.ensure, live, false)

      preserving_flow_control do
        # `break`, `next`, `return` and exceptions leave the handler
        # through the `ensure` clause, which might read the variables.
        @flow = @flow.map do |jump_live|
          propagate_through(node.ensure, jump_live, false)
        end

        after_body = propagate_through(node.else, post_ensure, mark)

        # Rescue branches handle exceptions raised at any point in the body,
        # so collect all variables they need.
        rescue_live = LiveSet.new
        node.rescues.try &.each do |rescue_node|
          rescue_live.concat(propagate_through(rescue_node, post_ensure, mark))
        end
        @flow = @flow.copy_with(raise_live: @flow.raise_live | rescue_live)

        # Conservatively consider the rescue-needed variables live
        # at both ends of the body, i.e. for macro expansions.
        propagate_through(node.body, after_body | rescue_live, mark) | rescue_live
      end
    end

    private def propagate_through(node : Crystal::Rescue, live : LiveSet, mark = true) : LiveSet
      live = propagate_through(node.body, live, mark)

      # The rescue variable (if any) gets assigned on entering the branch
      if (name = node.name) && find_assignment(node, name)
        live = remove_from_live_set(node, name, live, mark)
      end
      live
    end

    private def propagate_through(node : Crystal::BinaryOp, live : LiveSet, mark = true) : LiveSet
      # Right side is conditional, so union with entry state
      right_live = propagate_through(node.right, live, mark)

      propagate_through(node.left, right_live | live, mark)
    end

    private def propagate_through(node : Crystal::Call, live : LiveSet, mark = true) : LiveSet
      live = propagate_through_no_return(node, live)
      live = propagate_through_raise(live)

      live = propagate_through(node.block, live, mark)
      live = propagate_through(node.block_arg, live, mark)
      live = propagate_through(node.named_args, live, mark)
      live = propagate_through(node.args, live, mark)
      live = propagate_through(node.obj, live, mark)

      # Bare `super` and `previous_def` (without parentheses) implicitly
      # forward all method arguments, making each argument live.
      if node.name.in?("super", "previous_def") && !node.has_parentheses? && node.args.empty?
        @scope.arguments.each do |arg|
          live = add_to_live_set(arg.name, live)
        end
      end
      live
    end

    {% for type in RAISING_NODES %}
      private def propagate_through(node : Crystal::{{ type.id }}, live : LiveSet, mark = true) : LiveSet
        propagate_through_children(node, propagate_through_raise(live), mark)
      end
    {% end %}

    {% for type in MACRO_NODES %}
      {% unless INNER_SCOPE_NODES.includes?(type) %}
        private def propagate_through(node : Crystal::{{ type.id }}, live : LiveSet, mark = true) : LiveSet
          propagate_through_macro(live) | macro_reads(node)
        end
      {% end %}
    {% end %}

    private def propagate_through(node : Crystal::Return, live : LiveSet, mark = true) : LiveSet
      propagate_through(node.exp, @flow.return_live, mark)
    end

    private def propagate_through(node : Crystal::Break, live : LiveSet, mark = true) : LiveSet
      propagate_through(node.exp, @flow.break_live, mark)
    end

    private def propagate_through(node : Crystal::Next, live : LiveSet, mark = true) : LiveSet
      propagate_through(node.exp, @flow.next_live, mark)
    end

    # Inner scope nodes: don't descend into nested scopes, but since they
    # can read the current values of the variables they reference (i.e. blocks),
    # treat these as being read at the location of the inner scope
    {% for type in INNER_SCOPE_NODES %}
      private def propagate_through(node : Crystal::{{ type.id }}, live : LiveSet, mark = true) : LiveSet
        {% if MACRO_NODES.includes?(type) %}
          live = propagate_through_macro(live)
        {% end %}

        if reads = @inner_scope_reads[node.object_id]?
          live | reads
        else
          live
        end
      end
    {% end %}

    private def propagate_through(node : Crystal::ASTNode, live : LiveSet, mark = true) : LiveSet
      propagate_through_children(node, live, mark)
    end

    private def propagate_through_children(node : Crystal::ASTNode, live : LiveSet, mark) : LiveSet
      children = [] of Crystal::ASTNode
      node.accept_children(ChildCollector.new(children))

      propagate_through(children, live, mark)
    end

    private def propagate_through_loop(node : Crystal::While | Crystal::Until, live : LiveSet, mark) : LiveSet
      cond, body = node.cond, node.body

      # Endless loops (i.e. `while true`) are never left through
      # the condition, so the code following them is reached only by `break`.
      cond_exit_live = endless_loop?(node) ? LiveSet.new : live

      preserving_flow_control do
        # `break` exits to post-loop code, `next` jumps to loop condition.
        @flow = @flow.copy_with(break_live: live)
        entry_live = cond_exit_live

        MAX_FIXED_POINT_ITERATIONS.times do
          cond_live = propagate_through(cond, entry_live, false)
          @flow = @flow.copy_with(next_live: cond_live)

          body_live = propagate_through(body, cond_live, false)
          new_entry = body_live | cond_exit_live

          break if new_entry == entry_live
          entry_live = new_entry
        end

        # Final pass with marking enabled using the converged live set
        cond_live = propagate_through(cond, entry_live, mark)
        @flow = @flow.copy_with(next_live: cond_live)

        propagate_through(body, cond_live, mark)

        cond_live
      end
    end

    # Returns the variables live after the *node* call, which in case of
    # the calls never returning (`raise`, `exit`, `abort` and `loop` without
    # a `break`) aren't the ones read by the (unreachable) code following them,
    # but the ones live when raising (i.e. read by `rescue` / `ensure`),
    # returning or leaving the scope.
    private def propagate_through_no_return(node : Crystal::Call, live : LiveSet) : LiveSet
      case
      when raise?(node)
        @flow.raise_live
      when exit?(node), abort?(node)
        @exit_live
      when endless_loop_call?(node)
        # the block might `return` (raising is handled by the caller)
        @flow.return_live
      else
        live
      end
    end

    # Returns `true` if the *node* is a `loop do ... end` call never left by `break`.
    private def endless_loop_call?(node : Crystal::Call) : Bool
      return false unless loop?(node) && (block = node.block)

      !LoopBreakVisitor.new(block.body).found?
    end

    # Returns `true` if the *node* is a loop never left through its condition.
    private def endless_loop?(node : Crystal::While | Crystal::Until) : Bool
      case node
      in Crystal::While then node.cond.true_literal?
      in Crystal::Until then node.cond.false_literal?
      end
    end

    # Adds the variables live on any of the jumps, since the (unknown) code
    # expanded from a macro might `break`, `next`, `return` or raise at this point.
    private def propagate_through_macro(live : LiveSet) : LiveSet
      merge_live_sets(live, @flow.live)
    end

    # Adds the variables live when an exception is raised at this point.
    private def propagate_through_raise(live : LiveSet) : LiveSet
      merge_live_sets(live, @flow.raise_live)
    end

    # Returns the union of the live sets, reusing *live* if it includes *other*.
    private def merge_live_sets(live : LiveSet, other : LiveSet) : LiveSet
      other.subset_of?(live) ? live : live | other
    end

    # Restores the flow control overwritten within the block.
    private def preserving_flow_control(&)
      outer = @flow
      begin
        yield
      ensure
        @flow = outer
      end
    end
  end
end
