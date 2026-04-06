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
    alias LiveSet = Set(String)

    # Maximum iterations for fixed-point convergence in loops.
    # In practice, convergence happens in 2-3 iterations since the live set
    # can only grow monotonically and is bounded by the number of variables.
    private MAX_FIXED_POINT_ITERATIONS = 100

    private BRANCH_NODES      = %w[If Unless]
    private LOOP_NODES        = %w[While Until]
    private CASE_NODES        = %w[Case Select]
    private INNER_SCOPE_NODES = %w[
      Block Def ProcLiteral ClassDef ModuleDef EnumDef
      LibDef FunDef TypeDef CStructOrUnionDef TypeOf
      Macro MacroIf MacroFor
    ]

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
      entry_live = body ? propagate_through(body, LiveSet.new) : LiveSet.new

      Result.new(@dead_stores, entry_live)
    end

    record Result, dead_stores : Array(Assignment), entry_live_set : LiveSet

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

    # ameba:disable Metrics/CyclomaticComplexity
    private def scope_body(node)
      case node
      when Crystal::Def               then node.body
      when Crystal::FunDef            then node.body
      when Crystal::Block             then node.body
      when Crystal::ClassDef          then node.body
      when Crystal::ModuleDef         then node.body
      when Crystal::LibDef            then node.body
      when Crystal::CStructOrUnionDef then node.body
      when Crystal::Assign            then node.value
      when Crystal::OpAssign          then node.value
      when Crystal::ProcLiteral       then node.def.body
      when Crystal::EnumDef           then Crystal::Expressions.from(node.members)
      when Crystal::TypeOf            then Crystal::Expressions.from(node.expressions)
      when Crystal::Expressions       then node
      else                                 node
      end
    end

    private def inner_scope_node?(node)
      @inner_scope_nodes.includes?(node.object_id)
    end

    private def find_assignment(node, var_name) : Assignment?
      @assignment_map[{var_name, node.object_id}]?
    end

    # Records a dead store if the variable is not in the live set.
    private def mark_dead_store(assign_node, var_name, live : LiveSet) : Nil
      return if live.includes?(var_name)

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

    private def propagate_through(node : Crystal::Nop, live : LiveSet, mark = true) : LiveSet
      live
    end

    private def propagate_through(node : Crystal::Expressions, live : LiveSet, mark = true) : LiveSet
      node.expressions.reverse_each do |exp|
        live = propagate_through(exp, live, mark)
      end
      live
    end

    private def propagate_through(node : Crystal::Assign, live : LiveSet, mark = true) : LiveSet
      return live if inner_scope_node?(node)

      target = node.target
      unless target.is_a?(Crystal::Var) && @var_names.includes?(target.name)
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
      unless target.is_a?(Crystal::Var) && @var_names.includes?(target.name)
        live = propagate_through(node.value, live, mark)
        return propagate_through(target, live, mark)
      end

      # OpAssign both writes and reads the variable (x += 1 means x = x + 1).
      # Mark the dead store if the result is never read, then ensure the
      # variable is live (since the op-assign reads the current value).
      mark_dead_store(node, target.name, live) if mark
      unless live.includes?(target.name)
        live = live.dup
        live.add(target.name)
      end
      propagate_through(node.value, live, mark)
    end

    private def propagate_through(node : Crystal::MultiAssign, live : LiveSet, mark = true) : LiveSet
      node.targets.reverse_each do |target|
        if target.is_a?(Crystal::Var) && @var_names.includes?(target.name)
          live = remove_from_live_set(node, target.name, live, mark)
        end
      end
      node.values.reverse_each do |value|
        live = propagate_through(value, live, mark)
      end
      live
    end

    private def propagate_through(node : Crystal::UninitializedVar, live : LiveSet, mark = true) : LiveSet
      var = node.var
      if var.is_a?(Crystal::Var) && @var_names.includes?(var.name)
        live = remove_from_live_set(node, var.name, live, mark)
      end
      live
    end

    private def propagate_through(node : Crystal::TypeDeclaration, live : LiveSet, mark = true) : LiveSet
      var = node.var
      if var.is_a?(Crystal::Var) && @var_names.includes?(var.name)
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
      if @var_names.includes?(node.name) && !live.includes?(node.name)
        live = live.dup
        live.add(node.name)
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
      post_ensure = (body = node.ensure) ? propagate_through(body, live, mark) : live
      after_body = (body = node.else) ? propagate_through(body, post_ensure, mark) : post_ensure

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
          if @var_names.includes?(name) && !live.includes?(name)
            live = live.dup
            live.add(name)
          end
        end
        return live
      end

      node.block_arg.try do |arg|
        live = propagate_through(arg, live, mark)
      end

      node.named_args.try &.reverse_each do |named_arg|
        live = propagate_through(named_arg.value, live, mark)
      end

      node.args.reverse_each do |arg|
        live = propagate_through(arg, live, mark)
      end

      node.obj.try do |obj|
        live = propagate_through(obj, live, mark)
      end

      live
    end

    private def propagate_through(node : Crystal::Return, live : LiveSet, mark = true) : LiveSet
      target_live = LiveSet.new
      node.exp.try do |exp|
        target_live = propagate_through(exp, target_live, mark)
      end
      target_live
    end

    private def propagate_through(node : Crystal::Break, live : LiveSet, mark = true) : LiveSet
      target_live = @break_live || LiveSet.new
      node.exp.try do |exp|
        target_live = propagate_through(exp, target_live, mark)
      end
      target_live
    end

    private def propagate_through(node : Crystal::Next, live : LiveSet, mark = true) : LiveSet
      target_live = @next_live || LiveSet.new
      node.exp.try do |exp|
        target_live = propagate_through(exp, target_live, mark)
      end
      target_live
    end

    # Inner scope nodes: don't descend into nested scopes
    {% for type in INNER_SCOPE_NODES %}
      private def propagate_through(node : Crystal::{{ type.id }}, live : LiveSet, mark = true) : LiveSet
        live
      end
    {% end %}

    private def propagate_through(node, live : LiveSet, mark = true) : LiveSet
      children = [] of Crystal::ASTNode
      node.accept_children(ChildCollector.new(children))
      children.reverse_each do |child|
        live = propagate_through(child, live, mark)
      end
      live
    end

    private def propagate_through_loop(cond, body, live : LiveSet, mark) : LiveSet
      # Save outer loop context before overwriting
      outer_break = @break_live
      outer_next = @next_live

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

      @break_live = outer_break
      @next_live = outer_next

      converged_cond_live
    end

    private def propagate_through_case(node : Crystal::Case | Crystal::Select, live : LiveSet, mark) : LiveSet
      branch_lives = LiveSet.new

      node.whens.each do |when_node|
        when_live = propagate_through(when_node.body, live, mark)
        when_node.conds.reverse_each do |cond|
          when_live = propagate_through(cond, when_live, mark)
        end
        branch_lives.concat(when_live)
      end

      else_live = (body = node.else) ? propagate_through(body, live, mark) : live
      branch_lives.concat(else_live)

      if node.is_a?(Crystal::Case) && (cond = node.cond)
        branch_lives = propagate_through(cond, branch_lives, mark)
      end

      branch_lives
    end

    private class ChildCollector < Crystal::Visitor
      def initialize(@children : Array(Crystal::ASTNode))
      end

      def visit(node : Crystal::ASTNode)
        @children << node
        false
      end
    end
  end
end
