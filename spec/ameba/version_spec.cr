require "../spec_helper"

private def build_ameba_version(string)
  Ameba::Version.new(SemanticVersion.parse(string))
end

module Ameba
  describe Version do
    context "#to_s" do
      it "outputs full version string for non-release version" do
        version = build_ameba_version("1.2.3-dev+foo")
        version.to_s.should eq "1.2.3-dev+foo"
      end

      it "outputs simple version string for release version" do
        version = build_ameba_version("1.2.3+foo")
        version.to_s.should eq "1.2.3"
      end
    end

    context "#dev?" do
      it "returns `true` if the version pre-release identifiers contain only `dev`" do
        version = build_ameba_version("1.2.3-dev")
        version.dev?.should be_true
      end

      it "returns `true` if the version pre-release identifiers contain `dev`" do
        version = build_ameba_version("1.2.3-dev.arm64")
        version.dev?.should be_true
      end

      it "returns `false` if the version pre-release identifiers do not contain `dev`" do
        version = build_ameba_version("1.2.3")
        version.dev?.should be_false

        version = build_ameba_version("1.2.3-devo")
        version.dev?.should be_false
      end
    end

    context "#production?" do
      it "returns `true` if the version does not contain pre-release identifiers" do
        version = build_ameba_version("1.2.3")
        version.production?.should be_true
      end

      it "ignores build metadata" do
        version = build_ameba_version("1.2.3+foo")
        version.production?.should be_true
      end

      it "returns `false` if the version contains pre-release identifiers" do
        version = build_ameba_version("1.2.3-foo")
        version.production?.should be_false
      end
    end

    context "#simple" do
      it "returns the simple version string" do
        version = build_ameba_version("1.2.3-dev+foo")
        version.simple.to_s.should eq "1.2.3"
      end
    end
  end
end
