module Ameba::Ext::Range
  {% unless Range.has_method?(:overlaps?) %}
    # Returns whether the two ranges overlap.
    def overlaps?(other : Range) : Bool
      case
      when self.begin == self.end
        other.begin < self.begin < other.end
      when other.begin == other.end
        self.begin < other.begin < self.end
      else
        self.begin < other.end && other.begin < self.end
      end
    end
  {% end %}

  {% unless Range.has_method?(:crosses?) %}
    # Returns whether two ranges partially overlap without containing each other.
    def crosses?(other : Range) : Bool
      self.begin < other.begin < self.end < other.end ||
        other.begin < self.begin < other.end < self.end
    end
  {% end %}
end

struct Range(B, E)
  include Ameba::Ext::Range
end
