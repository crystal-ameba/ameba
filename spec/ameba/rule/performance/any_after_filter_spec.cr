require "../../../spec_helper"

module Ameba::Rule::Performance
  describe AnyAfterFilter do
    subject = AnyAfterFilter.new

    it "passes if there is no potential performance improvements" do
      expect_no_issues subject, <<-CRYSTAL
        [1, 2, 3].select { |e| e > 1 }.any? { |e| e.zero? }
        [1, 2, 3].select { |e| e > 1 }.any?(&.zero?)
        [1, 2, 3].reject { |e| e > 1 }.any?(&.zero?)
        [1, 2, 3].select { |e| e > 1 }.any?(&block)
        [1, 2, 3].select { |e| e > 1 }
        [1, 2, 3].reject { |e| e > 1 }
        [1, 2, 3].any? { |e| e > 1 }
        CRYSTAL
    end

    it "passes if filter has arguments" do
      expect_no_issues subject, <<-CRYSTAL
        [1, 2, 3].select(1) { |e| e > 1 }.any?
        CRYSTAL
    end

    it "passes if filter has no block" do
      expect_no_issues subject, <<-CRYSTAL
        [1, 2, 3].select.any?
        [1, 2, 3].reject.any?
        CRYSTAL
    end

    it "does not report if source is a spec" do
      expect_no_issues subject, <<-CRYSTAL, "source_spec.cr"
        [1, 2, 3].select { |e| e > 2 }.any?
        CRYSTAL
    end

    it "reports if there is select followed by any? without a block" do
      source = expect_issue subject, <<-CRYSTAL
        [1, 2, 3].select { |e| e > 2 }.any?
                # ^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `any? {...}` instead of `select {...}.any?`
        [1, 2, 3].select(&.odd?).any?
                # ^^^^^^^^^^^^^^^^^^^ error: Use `any? {...}` instead of `select {...}.any?`
        [1, 2, 3].map(&block).any?
                # ^^^^^^^^^^^^^^^^ error: Use `any? {...}` instead of `map {...}.any?`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        [1, 2, 3].any? { |e| e > 2 }
        [1, 2, 3].any?(&.odd?)
        [1, 2, 3].any?(&block)
        CRYSTAL
    end
    it "autocorrects multi-line block" do
      source = expect_issue subject, <<-CRYSTAL
        [1, 2, 3].select do |e|
                # ^^^^^^^^^^^^^ error: Use `any? {...}` instead of `select {...}.any?`
          e > 2
        end.any?
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        [1, 2, 3].any? do |e|
          e > 2
        end
        CRYSTAL
    end

    it "autocorrects when followed by another call" do
      source = expect_issue subject, <<-CRYSTAL
        [1, 2, 3].select(&.odd?).any?.to_s
                # ^^^^^^^^^^^^^^^^^^^ error: Use `any? {...}` instead of `select {...}.any?`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        [1, 2, 3].any?(&.odd?).to_s
        CRYSTAL
    end

    it "autocorrects chained receiver across newlines" do
      source = expect_issue subject, <<-CRYSTAL
        [1, 2, 3]
          .select(&.odd?).any?
         # ^^^^^^^^^^^^^^^^^^^ error: Use `any? {...}` instead of `select {...}.any?`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        [1, 2, 3]
          .any?(&.odd?)
        CRYSTAL
    end

    it "autocorrects chained receiver across newlines (2)" do
      source = expect_issue subject, <<-CRYSTAL
        [1, 2, 3]
          .select(&.odd?)
         # ^^^^^^^^^^^^^^ error: Use `any? {...}` instead of `select {...}.any?`
          .any?
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        [1, 2, 3]
          .any?(&.odd?)
          #{""}
        CRYSTAL
    end

    it "reports if there is map followed by any? without a block" do
      source = expect_issue subject, <<-CRYSTAL
        [1, 2, 3].map { |e| e > 2 }.any?
                # ^^^^^^^^^^^^^^^^^^^^^^ error: Use `any? {...}` instead of `map {...}.any?`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        [1, 2, 3].any? { |e| e > 2 }
        CRYSTAL
    end

    it "reports if there is reject followed by any? without a block" do
      source = expect_issue subject, <<-CRYSTAL
        [1, 2, 3].reject { |e| e > 2 }.any?
                # ^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `any? {!...}` instead of `reject {...}.any?`
        CRYSTAL

      expect_no_corrections source
    end

    it "does not report if any? calls contains a block" do
      expect_no_issues subject, <<-CRYSTAL
        [1, 2, 3].select { |e| e > 2 }.any?(&.zero?)
        [1, 2, 3].reject { |e| e > 2 }.any?(&.zero?)
        CRYSTAL
    end

    context "macro" do
      it "reports in macro scope" do
        source = expect_issue subject, <<-CRYSTAL
          {{ [1, 2, 3].reject { |e| e > 2 }.any? }}
                     # ^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `any? {!...}` instead of `reject {...}.any?`
          CRYSTAL

        expect_no_corrections source
      end
    end
  end
end
