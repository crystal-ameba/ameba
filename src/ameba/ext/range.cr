# Helpers for half-open source ranges. Empty ranges represent insertions.
module Ameba::Ext::Range
  # Returns whether the effects of two ranges overlap. An insertion conflicts
  # with a replacement only when it falls strictly inside the replaced range.
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

  # Returns whether two ranges partially overlap without containing each other.
  def crosses?(other : Range) : Bool
    self.begin < other.begin < self.end < other.end ||
      other.begin < self.begin < other.end < self.end
  end
end

struct Range(B, E)
  include Ameba::Ext::Range
end
