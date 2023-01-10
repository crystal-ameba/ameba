require "../../../spec_helper"

module Ameba::Rule::Performance
  subject = FlattenAfterMap.new

  describe FlattenAfterMap do
    it "passes if there is no potential performance improvements" do
      expect_no_issues subject, <<-CRYSTAL
        %w[Alice Bob].flat_map(&.chars)
        CRYSTAL
    end

    it "reports if there is map followed by flatten call" do
      expect_issue subject, <<-CRYSTAL
        %w[Alice Bob].map(&.chars).flatten
                    # ^^^^^^^^^^^^^^^^^^^^ error: Use `flat_map {...}` instead of `map {...}.flatten`
        CRYSTAL
    end

    it "does not report is source is a spec" do
      expect_no_issues subject, path: "source_spec.cr", code: <<-CRYSTAL
        %w[Alice Bob].map(&.chars).flatten
        CRYSTAL
    end

    context "macro" do
      it "doesn't report in macro scope" do
        expect_no_issues subject, <<-CRYSTAL
          {{ %w[Alice Bob].map(&.chars).flatten }}
          CRYSTAL
      end
    end
  end
end
