require "../../spec_helper"

describe Range do
  describe "#overlaps?" do
    it "respects the exclusivity of touching endpoints" do
      (1..5).overlaps?(5..10).should be_true
      (5..10).overlaps?(1..5).should be_true
      (1...5).overlaps?(5..10).should be_false
      (5..10).overlaps?(1...5).should be_false
    end

    it "accepts contained and identical nonempty ranges" do
      (1...5).overlaps?(2...4).should be_true
      (2...4).overlaps?(1...5).should be_true
      (1...5).overlaps?(1...5).should be_true
    end

    it "distinguishes single-value ranges from empty ranges" do
      (2..2).overlaps?(1...3).should be_true
      (2..2).overlaps?(2..2).should be_true
      (2...2).overlaps?(1...3).should be_false
      (1...3).overlaps?(2...2).should be_false
      (2...2).overlaps?(2...2).should be_false
    end

    it "rejects disjoint and reversed ranges" do
      (1..3).overlaps?(4..6).should be_false
      (4..6).overlaps?(1..3).should be_false
      (3..1).overlaps?(1..5).should be_false
      (1..5).overlaps?(3...1).should be_false
    end

    it "supports beginless and endless ranges" do
      (..5).overlaps?(5..).should be_true
      (...5).overlaps?(5..).should be_false
      (5..).overlaps?(...5).should be_false
      (1..).overlaps?(..3).should be_true
    end
  end

  describe "#crosses?" do
    it "accepts partial overlap in either direction" do
      (1...5).crosses?(3...7).should be_true
      (3...7).crosses?(1...5).should be_true
    end

    it "respects the exclusivity of touching endpoints" do
      (1..5).crosses?(5..10).should be_true
      (5..10).crosses?(1..5).should be_true
      (1...5).crosses?(5..10).should be_false
      (5..10).crosses?(1...5).should be_false
    end

    it "distinguishes containment at equal endpoints" do
      (1...5).crosses?(2..5).should be_true
      (2..5).crosses?(1...5).should be_true
      (1..5).crosses?(2...5).should be_false
      (2...5).crosses?(1..5).should be_false
    end

    it "distinguishes containment at adjacent endpoints" do
      (3..5).crosses?(4...6).should be_false
      (4...6).crosses?(3..5).should be_false
      (3..5).crosses?(2...6).should be_false
      (3...4).crosses?(2..3).should be_false
      (2..3).crosses?(3...4).should be_false
      (3..5).crosses?(4...7).should be_true
    end

    it "supports beginless and endless ranges" do
      (...5).crosses?(2..5).should be_true
      (...5).crosses?(2...5).should be_false
      (..5).crosses?(5..).should be_true
      (1..).crosses?(..3).should be_true
      (1..).crosses?(2..).should be_false
    end

    it "rejects contained, identical, empty, and disjoint ranges" do
      (1...5).crosses?(2...4).should be_false
      (2...4).crosses?(1...5).should be_false
      (1...5).crosses?(1...5).should be_false
      (2...2).crosses?(1...3).should be_false
      (1...3).crosses?(2...2).should be_false
      (1..3).crosses?(4..6).should be_false
    end
  end
end
