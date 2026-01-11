require "./spec_helper"

describe Ameba do
  context "VERSION" do
    it "contains a version-like string" do
      Ameba::VERSION.should match /^\d+\.\d+\.\d+/
    end
  end

  context ".version" do
    it "returns an `Ameba::Version` object" do
      Ameba.version.should be_a Ameba::Version
    end

    it "starts with `Ameba::VERSION`" do
      Ameba.version.to_s.should start_with Ameba::VERSION
    end
  end
end
