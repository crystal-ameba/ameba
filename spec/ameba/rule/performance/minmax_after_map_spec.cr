require "../../../spec_helper"

module Ameba::Rule::Performance
  subject = MinMaxAfterMap.new

  describe MinMaxAfterMap do
    it "passes if there are no potential performance improvements" do
      expect_no_issues subject, <<-CRYSTAL
        %w[Alice Bob].map { |name| name.size }.min(2)
        %w[Alice Bob].map { |name| name.size }.max(2)
        CRYSTAL
    end

    it "reports if there is a `min/max/minmax` call followed by `map`" do
      source = expect_issue subject, <<-CRYSTAL
        %w[Alice Bob].map { |name| name.size }.min
                    # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `min_of {...}` instead of `map {...}.min`.
        %w[Alice Bob].map(&.size).max.zero?
                    # ^^^^^^^^^^^^^^^ error: Use `max_of {...}` instead of `map {...}.max`.
        %w[Alice Bob].map(&.size).minmax?
                    # ^^^^^^^^^^^^^^^^^^^ error: Use `minmax_of? {...}` instead of `map {...}.minmax?`.
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        %w[Alice Bob].min_of { |name| name.size }
        %w[Alice Bob].max_of(&.size).zero?
        %w[Alice Bob].minmax_of?(&.size)
        CRYSTAL
    end

    it "does not report if source is a spec" do
      expect_no_issues subject, path: "source_spec.cr", code: <<-CRYSTAL
        %w[Alice Bob].map(&.size).min
        CRYSTAL
    end

    context "macro" do
      it "doesn't report in macro scope" do
        expect_no_issues subject, <<-CRYSTAL
          {{ %w[Alice Bob].map(&.size).min }}
          CRYSTAL
      end
    end
  end
end
