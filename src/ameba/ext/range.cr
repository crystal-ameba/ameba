module Ameba::Ext::Range
  {% unless Range.has_method?(:overlaps?) %}
    # Returns whether the two ranges have at least one value in common.
    def overlaps?(other : Range) : Bool
      if (begin_value = self.begin) && (end_value = self.end)
        return false if excludes_end? ? begin_value >= end_value : begin_value > end_value
      end

      if (other_begin = other.begin) && (other_end = other.end)
        return false if other.excludes_end? ? other_begin >= other_end : other_begin > other_end
      end

      if (end_value = self.end) && (other_begin = other.begin)
        return false if excludes_end? ? end_value <= other_begin : end_value < other_begin
      end

      if (other_end = other.end) && (begin_value = self.begin)
        return false if other.excludes_end? ? other_end <= begin_value : other_end < begin_value
      end

      true
    end
  {% end %}

  {% unless Range.has_method?(:crosses?) %}
    # Returns whether two ranges partially overlap without containing each other.
    #
    # An inclusive end reaches one value further than an exclusive one, so
    # `3..5` contains `4...6` and only `4...7` crosses it. A missing bound is
    # treated as infinite.
    def crosses?(other : Range) : Bool
      return false unless overlaps?(other)

      # Neither range contains the other
      !contains?(other) && !other.contains?(self)
    end

    # Returns whether `self` contains every value of *other*, assuming both
    # ranges have at least one value in common.
    #
    # A missing bound counts as infinite on its respective side. `Int` ends
    # are compared by value, with an inclusive end reaching one value further
    # than an exclusive one; other ends are compared by their endpoints.
    protected def contains?(other : Range) : Bool
      if (self_begin = self.begin) && (other_begin = other.begin)
        return false if self_begin > other_begin
      else
        # A bounded range cannot contain a beginless one
        return false unless self.begin.nil?
      end

      if (self_end = self.end) && (other_end = other.end)
        if self_end.is_a?(Int) && other_end.is_a?(Int)
          # An inclusive end reaches one value further than an exclusive one
          (excludes_end? ? self_end : self_end + 1) >=
            (other.excludes_end? ? other_end : other_end + 1)
        else
          self_end > other_end ||
            (self_end == other_end && (!excludes_end? || other.excludes_end?))
        end
      else
        # A bounded range cannot contain an endless one
        self.end.nil?
      end
    end
  {% end %}
end

struct Range(B, E)
  include Ameba::Ext::Range
end
