require "../../../spec_helper"

module Ameba::Rule::Performance
  subject = AnyInsteadOfEmpty.new

  describe AnyInsteadOfEmpty do
    it "passes if there is no potential performance improvements" do
      expect_no_issues subject, <<-CRYSTAL
        [1, 2, 3].any?(&.zero?)
        [1, 2, 3].any?(String)
        [1, 2, 3].any?(1..3)
        [1, 2, 3].any? { |e| e > 1 }
        CRYSTAL
    end

    it "reports if there is any? call without a block nor argument" do
      source = expect_issue subject, <<-CRYSTAL
        [1, 2, 3].any?
                # ^^^^ error: Use `!{...}.empty?` instead of `{...}.any?`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        ![1, 2, 3].empty?
        CRYSTAL
    end

    it "does not report if source is a spec" do
      expect_no_issues subject, <<-CRYSTAL, "source_spec.cr"
        [1, 2, 3].any?
        CRYSTAL
    end

    context "macro" do
      it "reports in macro scope" do
        source = expect_issue subject, <<-CRYSTAL
          {{ [1, 2, 3].any? }}
                     # ^^^^ error: Use `!{...}.empty?` instead of `{...}.any?`
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          {{ ![1, 2, 3].empty? }}
          CRYSTAL
      end
    end
  end
end
