require "../../../spec_helper"

module Ameba::Rule::Performance
  subject = CompactAfterMap.new

  describe CompactAfterMap do
    it "passes if there is no potential performance improvements" do
      expect_no_issues subject, <<-CRYSTAL
        (1..3).compact_map(&.itself)
        CRYSTAL
    end

    it "passes if there is map followed by a bang call" do
      expect_no_issues subject, <<-CRYSTAL
        (1..3).map(&.itself).compact!
        CRYSTAL
    end

    it "reports if there is map followed by compact call" do
      expect_issue subject, <<-CRYSTAL
        (1..3).map(&.itself).compact
             # ^^^^^^^^^^^^^^^^^^^^^ error: Use `compact_map {...}` instead of `map {...}.compact`
        CRYSTAL
    end

    it "does not report if source is a spec" do
      expect_no_issues subject, path: "source_spec.cr", code: <<-CRYSTAL
        (1..3).map(&.itself).compact
        CRYSTAL
    end

    context "macro" do
      it "doesn't report in macro scope" do
        expect_no_issues subject, <<-CRYSTAL
          {{ [1, 2, 3].map(&.to_s).compact }}
          CRYSTAL
      end
    end
  end
end
