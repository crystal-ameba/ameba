class Ameba::Source::Rewriter
  # :nodoc:
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
      sibling_left, sibling_right = family[:sibling_left], family[:sibling_right]

      if fusible = family[:fusible]
        child = family[:child]
        child ||= [] of Action
        fuse_deletions(action, fusible, sibling_left + child + sibling_right)
      else
        extra_sibling =
          case
          when parent = family[:parent]
            # action should be a descendant of one of the children
            parent.combine(action)
          when child = family[:child]
            # or it should become the parent of some of the children,
            action.with(children: child).combine_children(action.children)
          else
            # or else it should become an additional child
            action
          end
        self.with(children: sibling_left + [extra_sibling] + sibling_right)
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
      fused_deletion = action.with(begin_pos: fused_begin_pos, end_pos: fused_end_pos)
      without_fusible.combine(fused_deletion)
    end

    # Similar to `@children.bsearch_index || size` except allows for a starting point
    protected def bsearch_child_index(from = 0, &)
      size = @children.size
      (from...size).bsearch { |i| yield @children[i] } || size
    end

    # Returns the children in a hierarchy with respect to *action*:
    #
    # - `:sibling_left`, `:sibling_right` (for those that are disjoint from *action*)
    # - `:parent` (in case one of our children contains *action*)
    # - `:child` (in case *action* strictly contains some of our children)
    # - `:fusible` (in case *action* overlaps some children but they can be fused in one deletion)
    #
    # In case a child has equal range to *action*, it is returned as `:parent`
    #
    # Reminder: an empty range 1...1 is considered disjoint from 1...10
    protected def analyze_hierarchy(action) # ameba:disable Metrics/CyclomaticComplexity
      # left_index is the index of the first child that isn't completely to the left of action
      left_index = bsearch_child_index { |child| child.end_pos > action.begin_pos }
      # right_index is the index of the first child that is completely on the right of action
      start = left_index == 0 ? 0 : left_index - 1 # See "corner case" below for reason of -1
      right_index = bsearch_child_index(start) { |child| child.begin_pos >= action.end_pos }
      center = right_index - left_index
      case center
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
      else
        overlap_left = @children[left_index].begin_pos <=> action.begin_pos
        overlap_right = @children[right_index - 1].end_pos <=> action.end_pos

        raise "Unable to compare begin pos" if overlap_left.nil?
        raise "Unable to compare end pos" if overlap_right.nil?

        # For one child to be the parent of action, we must have:
        if center == 1 && overlap_left <= 0 && overlap_right >= 0
          parent = @children[left_index]
        else
          # Otherwise consider all non disjoint elements (center) to be contained...
          contained = @children[left_index...right_index]
          fusible = [] of Action
          fusible << contained.shift if overlap_left < 0 # ... but check first and last one
          fusible << contained.pop if overlap_right > 0  # ... for overlaps
          fusible = nil if fusible.empty?
        end
      end

      {
        parent:        parent,
        sibling_left:  @children[0...left_index],
        sibling_right: @children[right_index...@children.size],
        fusible:       fusible,
        child:         contained,
      }
    end

    # Assumes *action* has the exact same range and has no children
    protected def merge(action)
      self.with(
        insert_before: "#{action.insert_before}#{insert_before}",
        replacement: action.replacement || @replacement,
        insert_after: "#{insert_after}#{action.insert_after}",
      ).combine_children(action.children)
    end
  end
end
