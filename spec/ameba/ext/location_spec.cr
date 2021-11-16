require "../../spec_helper"

describe Crystal::Location do
  subject = Crystal::Location.new(nil, 2, 3)

  describe "#with" do
    it "changes line number" do
      subject.with(line_number: 1).to_s.should eq ":1:3"
    end

    it "changes column number" do
      subject.with(column_number: 1).to_s.should eq ":2:1"
    end

    it "changes line and column numbers" do
      subject.with(line_number: 1, column_number: 2).to_s.should eq ":1:2"
    end
  end

  describe "#adjust" do
    it "adjusts line number" do
      subject.adjust(line_number: 1).to_s.should eq ":3:3"
    end

    it "adjusts column number" do
      subject.adjust(column_number: 1).to_s.should eq ":2:4"
    end

    it "adjusts line and column numbers" do
      subject.adjust(line_number: 1, column_number: 2).to_s.should eq ":3:5"
    end
  end

  describe "#seek" do
    it "adjusts column number if line offset is 1" do
      subject.seek(Crystal::Location.new(nil, 1, 2)).to_s.should eq ":2:4"
    end

    it "adjusts line number and changes column number if line offset is greater than 1" do
      subject.seek(Crystal::Location.new(nil, 2, 1)).to_s.should eq ":3:1"
    end

    it "adjusts line number and changes column number if line offset is less than 1" do
      subject.seek(Crystal::Location.new(nil, 0, 1)).to_s.should eq ":1:1"
    end

    it "raises exception if filenames don't match" do
      expect_raises(ArgumentError, "Mismatching filenames:\n  source.cr\n  source2.cr") do
        location = Crystal::Location.new("source.cr", 1, 1)
        location.seek(Crystal::Location.new("source2.cr", 1, 1))
      end
    end
  end
end
