require "../../../spec_helper"

module Ameba::Rule::Performance
  describe CompactAfterMap do
    subject = CompactAfterMap.new

    it "passes if there is no potential performance improvements" do
      expect_no_issues subject, <<-CRYSTAL
        (1..3).compact_map(&.itself)
        (1..3).compact_map(&block)
        CRYSTAL
    end

    it "passes if compact has arguments or a block" do
      expect_no_issues subject, <<-CRYSTAL
        (1..3).map(&.itself).compact(1)
        (1..3).map(&.itself).compact { |x| x }
        (1..3).map(1, 2) { |x| x }.compact
        CRYSTAL
    end

    it "passes if map has no block" do
      expect_no_issues subject, <<-CRYSTAL
        (1..3).map.compact
        CRYSTAL
    end

    it "passes if there is map followed by a bang call" do
      expect_no_issues subject, <<-CRYSTAL
        (1..3).map(&.itself).compact!
        CRYSTAL
    end

    it "reports and autocorrects if there is map followed by compact call" do
      source = expect_issue subject, <<-CRYSTAL
        (1..3).map(&.itself).compact
             # ^^^^^^^^^^^^^^^^^^^^^ error: Use `compact_map {...}` instead of `map {...}.compact`
        (1..3).map(&block).compact
             # ^^^^^^^^^^^^^^^^^^^ error: Use `compact_map {...}` instead of `map {...}.compact`
        (1..3).map { |i| i.to_s }.compact
             # ^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `compact_map {...}` instead of `map {...}.compact`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        (1..3).compact_map(&.itself)
        (1..3).compact_map(&block)
        (1..3).compact_map { |i| i.to_s }
        CRYSTAL
    end

    it "autocorrects multi-line block" do
      source = expect_issue subject, <<-CRYSTAL
        (1..3).map do |i|
             # ^^^^^^^^^^ error: Use `compact_map {...}` instead of `map {...}.compact`
          i.to_s
        end.compact
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        (1..3).compact_map do |i|
          i.to_s
        end
        CRYSTAL
    end

    it "autocorrects when followed by another call" do
      source = expect_issue subject, <<-CRYSTAL
        (1..3).map(&.itself).compact.first
             # ^^^^^^^^^^^^^^^^^^^^^ error: Use `compact_map {...}` instead of `map {...}.compact`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        (1..3).compact_map(&.itself).first
        CRYSTAL
    end

    it "autocorrects chained receiver with shorthand block" do
      source = expect_issue subject, <<-CRYSTAL
        %w[Alice Bob].map(&.match(/^A./)).compact
                    # ^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `compact_map {...}` instead of `map {...}.compact`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        %w[Alice Bob].compact_map(&.match(/^A./))
        CRYSTAL
    end

    it "autocorrects chained receiver across newlines" do
      source = expect_issue subject, <<-CRYSTAL
        (1..3)
          .map(&.itself).compact
         # ^^^^^^^^^^^^^^^^^^^^^ error: Use `compact_map {...}` instead of `map {...}.compact`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        (1..3)
          .compact_map(&.itself)
        CRYSTAL
    end

    it "autocorrects chained receiver across newlines (2)" do
      source = expect_issue subject, <<-CRYSTAL
        (1..3)
          .map(&.itself)
         # ^^^^^^^^^^^^^ error: Use `compact_map {...}` instead of `map {...}.compact`
          .compact
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        (1..3)
          .compact_map(&.itself)
          #{""}
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
