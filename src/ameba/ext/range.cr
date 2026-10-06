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
    def crosses?(other : Range) : Bool
      return false unless overlaps?(other)

      self.begin < other.begin &&
        (self.end < other.end || (self.end == other.end && excludes_end? && !other.excludes_end?)) ||
        other.begin < self.begin &&
          (other.end < self.end || (other.end == self.end && other.excludes_end? && !excludes_end?))
    end
  {% end %}
end

struct Range(B, E)
  include Ameba::Ext::Range
end
