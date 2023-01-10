require "../../../spec_helper"

module Ameba::Rule::Performance
  subject = MapInsteadOfBlock.new

  describe MapInsteadOfBlock do
    it "passes if there is no potential performance improvements" do
      expect_no_issues subject, <<-CRYSTAL
        (1..3).sum(&.*(2))
        (1..3).product(&.*(2))
        CRYSTAL
    end

    it "reports if there is map followed by sum without a block" do
      expect_issue subject, <<-CRYSTAL
        (1..3).map(&.to_u64).sum
             # ^^^^^^^^^^^^^^^^^ error: Use `sum {...}` instead of `map {...}.sum`
        CRYSTAL
    end

    it "does not report if source is a spec" do
      expect_no_issues subject, path: "source_spec.cr", code: <<-CRYSTAL
        (1..3).map(&.to_s).join
        CRYSTAL
    end

    it "reports if there is map followed by sum without a block (with argument)" do
      expect_issue subject, <<-CRYSTAL
        (1..3).map(&.to_u64).sum(0)
             # ^^^^^^^^^^^^^^^^^ error: Use `sum {...}` instead of `map {...}.sum`
        CRYSTAL
    end

    it "reports if there is map followed by sum with a block" do
      expect_issue subject, <<-CRYSTAL
        (1..3).map(&.to_u64).sum(&.itself)
             # ^^^^^^^^^^^^^^^^^ error: Use `sum {...}` instead of `map {...}.sum`
        CRYSTAL
    end

    context "macro" do
      it "doesn't report in macro scope" do
        expect_no_issues subject, <<-CRYSTAL
          {{ [1, 2, 3].map(&.to_u64).sum }}
          CRYSTAL
      end
    end
  end
end
