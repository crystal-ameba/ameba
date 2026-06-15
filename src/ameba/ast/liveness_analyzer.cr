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

    alias LiveSet = Set(String)

    record Result,
      dead_stores : Array(Assignment),
      entry_live_set : LiveSet

    # Maximum iterations for fixed-point convergence in loops.
    # In practice, convergence happens in 2-3 iterations since the live set
    # can only grow monotonically and is bounded by the number of variables.
    private MAX_FIXED_POINT_ITERATIONS = 100

    @dead_stores = [] of Assignment
    @var_names : Set(String)
    @assignment_map : Hash(Tuple(String, UInt64), Assignment)
    @inner_scope_nodes : Set(UInt64)

    # Live sets for loop flow control: `break` exits to post-loop,
    # `next` jumps to loop condition. Without these, assignments
    # before break/next would be incorrectly marked as dead.
    @break_live : LiveSet?
    @next_live : LiveSet?

    def initialize(@scope : Scope)
      @var_names = @scope.variables.map(&.name).to_set
      @assignment_map = build_assignment_map
      @inner_scope_nodes = @scope.inner_scopes.map(&.node.object_id).to_set
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
      entry_live = propagate_through(body, LiveSet.new)

      Result.new(@dead_stores, entry_live)
    end

    private def build_assignment_map
      map = Hash(Tuple(String, UInt64), Assignment).new

      @scope.variables.each do |var|
        var.assignments.each do |assign|
          key = {var.name, assign.node.object_id}
          map[key] ||= assign
        end
      end
      map
    end

    private def inner_scope_node?(node)
      @inner_scope_nodes.includes?(node.object_id)
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
      unless target.is_a?(Crystal::Var) && target.name.in?(@var_names)
        live = propagate_through(node.value, live, mark)
        return propagate_through(target, live, mark)
      end

      # Only remove from live set if this assignment is tracked in the scope.
      # Untracked assignments (e.g. inside record/accessor macro args) are transparent.
      if find_assignment(node, target.name)
        live = remove_from_live_set(node, target.name, live, mark)
      end
      propagate_through(node.value, live, mark)
    end

    private def propagate_through(node : Crystal::OpAssign, live : LiveSet, mark = true) : LiveSet
      return live if inner_scope_node?(node)

      target = node.target
      unless target.is_a?(Crystal::Var) && target.name.in?(@var_names)
        live = propagate_through(node.value, live, mark)
        return propagate_through(target, live, mark)
      end

      # OpAssign both writes and reads the variable (x += 1 means x = x + 1).
      # Mark the dead store if the result is never read, then ensure the
      # variable is live (since the op-assign reads the current value).
      mark_dead_store(node, target.name, live) if mark
      unless target.name.in?(live)
        live = live.dup
        live.add(target.name)
      end
      propagate_through(node.value, live, mark)
    end

    private def propagate_through(node : Crystal::MultiAssign, live : LiveSet, mark = true) : LiveSet
      node.targets.reverse_each do |target|
        if target.is_a?(Crystal::Var) && target.name.in?(@var_names)
          live = remove_from_live_set(node, target.name, live, mark)
        end
      end
      propagate_through(node.values, live, mark)
    end

    private def propagate_through(node : Crystal::UninitializedVar, live : LiveSet, mark = true) : LiveSet
      var = node.var
      if var.is_a?(Crystal::Var) && var.name.in?(@var_names)
        live = remove_from_live_set(node, var.name, live, mark)
      end
      live
    end

    private def propagate_through(node : Crystal::TypeDeclaration, live : LiveSet, mark = true) : LiveSet
      var = node.var
      if var.is_a?(Crystal::Var) && var.name.in?(@var_names)
        if value = node.value
          live = remove_from_live_set(node, var.name, live, mark)
          live = propagate_through(value, live, mark)
        else
          # Type declarations without a value are type restrictions, not
          # assignments — don't mark as dead. Since Crystal requires the
          # variable to be previously undefined, kill it from the live set
          # as no prior references can exist.
          live = remove_from_live_set(node, var.name, live, mark: false)
        end
      end
      live
    end

    private def propagate_through(node : Crystal::Var, live : LiveSet, mark = true) : LiveSet
      name = node.name
      if name.in?(@var_names) && !name.in?(live)
        live = live.dup
        live.add(name)
      end
      live
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
        propagate_through_loop(node.cond, node.body, live, mark)
      end
    {% end %}

    {% for type in CASE_NODES %}
      private def propagate_through(node : Crystal::{{ type.id }}, live : LiveSet, mark = true) : LiveSet
        propagate_through_case(node, live, mark)
      end
    {% end %}

    private def propagate_through(node : Crystal::ExceptionHandler, live : LiveSet, mark = true) : LiveSet
      post_ensure = propagate_through(node.ensure, live, mark)
      after_body = propagate_through(node.else, post_ensure, mark)

      # Rescue branches handle exceptions thrown at any point in the body,
      # so collect all variables they need.
      rescue_live = LiveSet.new
      node.rescues.try &.each do |rescue_node|
        rescue_live.concat(propagate_through(rescue_node.body, post_ensure, mark))
      end

      # Body can throw at any point, so variables live in any rescue
      # branch must also be considered live throughout the body.
      # Union rescue_live because rescue-needed variables are live before the entire handler.
      body_live = propagate_through(node.body, after_body | rescue_live, mark)
      body_live | rescue_live
    end

    private def propagate_through(node : Crystal::BinaryOp, live : LiveSet, mark = true) : LiveSet
      # Right side is conditional, so union with entry state
      right_live = propagate_through(node.right, live, mark)

      propagate_through(node.left, right_live | live, mark)
    end

    private def propagate_through(node : Crystal::Call, live : LiveSet, mark = true) : LiveSet
      # Bare `super` and `previous_def` (without parentheses) implicitly
      # forward all method arguments, making each argument live.
      if node.name.in?("super", "previous_def") && !node.has_parentheses? && node.args.empty?
        @scope.arguments.each do |arg|
          name = arg.name
          if name.in?(@var_names) && !name.in?(live)
            live = live.dup
            live.add(name)
          end
        end
        return live
      end

      live = propagate_through(node.block_arg, live, mark)
      live = propagate_through(node.named_args, live, mark)
      live = propagate_through(node.args, live, mark)
      live = propagate_through(node.obj, live, mark)
      live
    end

    private def propagate_through(node : Crystal::Return, live : LiveSet, mark = true) : LiveSet
      propagate_through(node.exp, LiveSet.new, mark)
    end

    private def propagate_through(node : Crystal::Break, live : LiveSet, mark = true) : LiveSet
      propagate_through(node.exp, @break_live || LiveSet.new, mark)
    end

    private def propagate_through(node : Crystal::Next, live : LiveSet, mark = true) : LiveSet
      propagate_through(node.exp, @next_live || LiveSet.new, mark)
    end

    # Inner scope nodes: don't descend into nested scopes
    {% for type in INNER_SCOPE_NODES %}
      private def propagate_through(node : Crystal::{{ type.id }}, live : LiveSet, mark = true) : LiveSet
        live
      end
    {% end %}

    private def propagate_through(node : Crystal::ASTNode, live : LiveSet, mark = true) : LiveSet
      children = [] of Crystal::ASTNode
      node.accept_children(ChildCollector.new(children))

      propagate_through(children, live, mark)
    end

    private def propagate_through_loop(cond, body, live : LiveSet, mark) : LiveSet
      # Save outer loop context before overwriting
      outer_break = @break_live
      outer_next = @next_live

      begin
        # `break` exits to post-loop code, `next` jumps to loop condition.
        @break_live = live
        entry_live = live.dup

        converged_cond_live = entry_live
        MAX_FIXED_POINT_ITERATIONS.times do
          @next_live = entry_live

          converged_cond_live = propagate_through(cond, entry_live, false)
          body_live = propagate_through(body, converged_cond_live, false)
          new_entry = body_live | live

          break if new_entry == entry_live
          entry_live = new_entry
        end

        # Final pass with marking enabled using the converged live set
        @next_live = entry_live

        cond_live = propagate_through(cond, entry_live, mark)
        propagate_through(body, cond_live, mark)

        converged_cond_live
      ensure
        @break_live = outer_break
        @next_live = outer_next
      end
    end

    private def propagate_through_case(node : Crystal::Case | Crystal::Select, live : LiveSet, mark) : LiveSet
      branch_lives = LiveSet.new

      node.whens.each do |when_node|
        when_live = propagate_through(when_node.body, live, mark)
        when_live = propagate_through(when_node.conds, when_live, mark)
        branch_lives.concat(when_live)
      end

      else_live = propagate_through(node.else, live, mark)
      branch_lives.concat(else_live)

      if node.is_a?(Crystal::Case) && (cond = node.cond)
        branch_lives = propagate_through(cond, branch_lives, mark)
      end

      branch_lives
    end
  end
end
