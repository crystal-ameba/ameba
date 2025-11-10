require "../../../spec_helper"

module Ameba::Rule::Lint
  describe LiteralInInterpolation do
    subject = LiteralInInterpolation.new

    it "passes with good interpolation examples" do
      expect_no_issues subject, <<-'CRYSTAL'
        "Hello, #{name}"
        "#{name}"
        "Name size: #{name.size}"
        "#{foo..}"
        CRYSTAL
    end

    it "fails if there is useless interpolation" do
      [
        %q("#{:Ary}"),
        %q("#{[1, 2, 3]}"),
        %q("#{true}"),
        %q("#{false}"),
        %q("here are #{4} cats"),
      ].each do |str|
        subject.catch(Source.new str).should_not be_valid
      end
    end

    it "works with magic constants (#593)" do
      expect_no_issues subject, <<-'CRYSTAL', "/home/foo/source.cr"
        "Hello from #{__FILE__} at line #{__LINE__} in #{__DIR__}"
        CRYSTAL
    end

    it "reports if there is a literal in interpolation" do
      expect_issue subject, <<-'CRYSTAL'
        "Hello, #{:world} from #{:ameba}"
                # ^^^^^^ error: Literal value found in interpolation
                               # ^^^^^^ error: Literal value found in interpolation
        CRYSTAL
    end
  end
end
