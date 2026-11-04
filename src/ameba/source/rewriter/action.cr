class Ameba::Source::Rewriter
  # :nodoc:
  #
  # Actions are arranged in a tree and get combined so that:
  # - children are strictly contained by their parent
  # - siblings all disjoint from one another and ordered
  # - only actions with `replacement == nil` may have children
  class Action
    getter begin_pos : Int32
    getter end_pos : Int32
    getter replacement : String?
    getter insert_before : String
    getter insert_after : String
    protected getter children : Array(Action)

    def initialize(@begin_pos,
                   @end_pos,
                   @insert_before = "",
                   @replacement = nil,
                   @insert_after = "",
                   @children = [] of Action)
    end

    def combine(action)
      return self if action.empty? # Ignore empty action

      if action.begin_pos == @begin_pos && action.end_pos == @end_pos
        merge(action)
      else
        place_in_hierarchy(action)
      end
    end

    def empty?
      replacement = @replacement

      @insert_before.empty? &&
        @insert_after.empty? &&
        @children.empty? &&
        (replacement.nil? ||
          (replacement.empty? && @begin_pos == @end_pos))
    end

    def ordered_replacements
      replacement = @replacement

      reps = [] of {Int32, Int32, String}
      reps << {@begin_pos, @begin_pos, @insert_before} unless @insert_before.empty?
      reps << {@begin_pos, @end_pos, replacement} if replacement
      reps.concat(@children.flat_map(&.ordered_replacements))
      reps << {@end_pos, @end_pos, @insert_after} unless @insert_after.empty?
      reps
    end

    def insertion?
      replacement = @replacement

      !@insert_before.empty? ||
        !@insert_after.empty? ||
        (replacement && !replacement.empty?)
    end

    # Returns `true` if `#combine` would lose or fuse an edit when placing
    # *action* in this tree. It follows the same structural decisions.
    def conflicts_with?(action : self) : Bool
      if action.begin_pos == @begin_pos && action.end_pos == @end_pos
        return true if action.replacement && (@replacement || !@children.empty?)
        return action.children.any? { |child| conflicts_with?(child) }
      end
      # A replacement swallows everything placed inside of it
      return true if @replacement

      family = analyze_hierarchy(action)
      return true if family[:fusible]

      case
      when parent = family[:parent]
        parent.conflicts_with?(action)
      when action.replacement
        family[:contained].size > 0
      else
        action.children.any? { |child| conflicts_with?(child) }
      end
    end

    protected def with(*,
                       begin_pos = @begin_pos,
                       end_pos = @end_pos,
                       insert_before = @insert_before,
                       replacement = @replacement,
                       insert_after = @insert_after,
                       children = @children)
      children = [] of Action if replacement
      self.class.new(begin_pos, end_pos, insert_before, replacement, insert_after, children)
    end

    protected def place_in_hierarchy(action)
      family = analyze_hierarchy(action)
      left_index, right_index = family[:left_index], family[:right_index]

      if family[:fusible]
        contained = family[:contained]

        fusible = [] of Action
        fusible << @children[left_index] if contained.begin > left_index
        fusible << @children[right_index - 1] if contained.end < right_index

        fuse_deletions(action, fusible,
          @children[0...left_index] + @children[contained] + @children[right_index..])
      else
        extra_sibling =
          case
          when parent = family[:parent]
            # action should be a descendant of one of the children
            parent.combine(action)
          when family[:contained].size > 0
            # or it should become the parent of some of the children,
            action.with(children: @children[family[:contained]]).combine_children(action.children)
          else
            # or else it should become an additional child
            action
          end
        children = @children.dup
        children[left_index, right_index - left_index] = extra_sibling
        self.with(children: children)
      end
    end

    # Assumes *more_children* all contained within `@begin_pos...@end_pos`
    protected def combine_children(more_children)
      more_children.reduce(self) do |parent, new_child|
        parent.place_in_hierarchy(new_child)
      end
    end

    protected def fuse_deletions(action, fusible, other_siblings)
      without_fusible = self.with(children: other_siblings)
      fusible = [action] + fusible

      fused_begin_pos = fusible.min_of(&.begin_pos)
      fused_end_pos = fusible.max_of(&.end_pos)

      fused_deletion = action.with(
        begin_pos: fused_begin_pos,
        end_pos: fused_end_pos,
      )
      without_fusible.combine(fused_deletion)
    end

    # Similar to `@children.bsearch_index || size` except allows for a starting point
    protected def bsearch_child_index(from = 0, &)
      size = @children.size
      (from...size).bsearch { |i| yield @children[i] } || size
    end

    # Returns the position of children in a hierarchy with respect to *action*:
    #
    # - `:left_index`, `:right_index` (the children outside of those are disjoint from *action*)
    # - `:parent` (in case one of our children contains *action*)
    # - `:contained` (the indices of children *action* strictly contains)
    # - `:fusible` (in case *action* overlaps some children but they can be fused in one deletion)
    #
    # In case a child has equal range to *action*, it is returned as `:parent`
    #
    # NOTE: an empty range `1...1` is considered disjoint from `1...10`
    protected def analyze_hierarchy(action)
      # left_index is the index of the first child that isn't completely to the left of action
      left_index = bsearch_child_index do |child|
        child.end_pos > action.begin_pos
      end

      # right_index is the index of the first child that is completely on the right of action
      start = left_index == 0 ? 0 : left_index - 1 # See "corner case" below for reason of -1
      right_index = bsearch_child_index(start) do |child|
        child.begin_pos >= action.end_pos
      end

      contained = left_index...left_index
      fusible = false

      case center = right_index - left_index
      when 0
        # All children are disjoint from action, nothing else to do
      when -1
        # Corner case: if a child has empty range == action's range
        # then it will appear to be both disjoint and to the left of action,
        # as well as disjoint and to the right of action.
        # Since ranges are equal, we return it as parent
        left_index -= 1  # Fix indices, as otherwise this child would be
        right_index += 1 # considered as a sibling (both left and right!)

        parent = @children[left_index]
        contained = left_index...left_index
      else
        overlap_left = @children[left_index].begin_pos <=> action.begin_pos
        overlap_right = @children[right_index - 1].end_pos <=> action.end_pos

        # For one child to be the parent of action, we must have:
        if center == 1 && overlap_left <= 0 && overlap_right >= 0
          parent = @children[left_index]
        else
          # Otherwise consider all non disjoint elements (center) to be contained...
          first = overlap_left < 0 ? left_index + 1 : left_index   # ... but check first and last one
          last = overlap_right > 0 ? right_index - 1 : right_index # ... for overlaps
          contained = first...last
          fusible = first != left_index || last != right_index
        end
      end

      {
        parent:      parent,
        left_index:  left_index,
        right_index: right_index,
        contained:   contained,
        fusible:     fusible,
      }
    end

    # Assumes *action* has the exact same range
    protected def merge(action)
      self.with(
        insert_before: "#{action.insert_before}#{insert_before}",
        replacement: action.replacement || @replacement,
        insert_after: "#{insert_after}#{action.insert_after}",
      ).combine_children(action.children)
    end
  end
end
