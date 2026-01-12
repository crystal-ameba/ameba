require "../spec_helper"

private def build_ameba_version(string)
  Ameba::Version.new(SemanticVersion.parse(string))
end

module Ameba
  describe Version do
    context "#to_s" do
      it "outputs the `version` string" do
        version = build_ameba_version("1.2.3")
        version.to_s.should eq version.version.to_s
      end
    end

    context "#version" do
      it "matches the version format" do
        version = build_ameba_version("1.2.3")
        version.version.to_s.should match /^\d+\.\d+\.\d+/
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

    context "#release_candidate?" do
      it "returns `true` for `rc` pre-release identifier followed by a number" do
        version = build_ameba_version("1.2.3-rc-1")
        version.release_candidate?.should be_true

        version = build_ameba_version("1.2.3-rc1")
        version.release_candidate?.should be_true

        version = build_ameba_version("1.2.3-RC1")
        version.release_candidate?.should be_false

        version = build_ameba_version("1.2.3-rc-x")
        version.release_candidate?.should be_false
      end

      it "returns `true` if the version pre-release identifiers contain only `rc`" do
        version = build_ameba_version("1.2.3-rc")
        version.release_candidate?.should be_true
      end

      it "returns `true` if the version pre-release identifiers contain `rc`" do
        version = build_ameba_version("1.2.3-rc.arm64")
        version.release_candidate?.should be_true
      end

      it "returns `false` if the version pre-release identifiers do not contain `rc`" do
        version = build_ameba_version("1.2.3-rcx")
        version.release_candidate?.should be_false
      end

      it "returns `false` if the version pre-release identifiers are empty" do
        version = build_ameba_version("1.2.3")
        version.release_candidate?.should be_false
      end
    end
  end
end
