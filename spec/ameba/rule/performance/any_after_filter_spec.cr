require "../../../spec_helper"

module Ameba::Rule::Performance
  subject = AnyAfterFilter.new

  describe AnyAfterFilter do
    it "passes if there is no potential performance improvements" do
      expect_no_issues subject, <<-CRYSTAL
        [1, 2, 3].select { |e| e > 1 }.any?(&.zero?)
        [1, 2, 3].reject { |e| e > 1 }.any?(&.zero?)
        [1, 2, 3].select { |e| e > 1 }
        [1, 2, 3].reject { |e| e > 1 }
        [1, 2, 3].any? { |e| e > 1 }
        CRYSTAL
    end

    it "reports if there is select followed by any? without a block" do
      source = expect_issue subject, <<-CRYSTAL
        [1, 2, 3].select { |e| e > 2 }.any?
                # ^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `any? {...}` instead of `select {...}.any?`
        CRYSTAL

      expect_no_corrections source
    end

    it "does not report if source is a spec" do
      expect_no_issues subject, <<-CRYSTAL, "source_spec.cr"
        [1, 2, 3].select { |e| e > 2 }.any?
        CRYSTAL
    end

    it "reports if there is reject followed by any? without a block" do
      source = expect_issue subject, <<-CRYSTAL
        [1, 2, 3].reject { |e| e > 2 }.any?
                # ^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `any? {...}` instead of `reject {...}.any?`
        CRYSTAL

      expect_no_corrections source
    end

    it "does not report if any? calls contains a block" do
      expect_no_issues subject, <<-CRYSTAL
        [1, 2, 3].select { |e| e > 2 }.any?(&.zero?)
        [1, 2, 3].reject { |e| e > 2 }.any?(&.zero?)
        CRYSTAL
    end

    context "properties" do
      it "#filter_names" do
        rule = AnyAfterFilter.new
        rule.filter_names = %w[select]

        expect_no_issues rule, <<-CRYSTAL
          [1, 2, 3].reject { |e| e > 2 }.any?
          CRYSTAL
      end
    end

    context "macro" do
      it "reports in macro scope" do
        source = expect_issue subject, <<-CRYSTAL
          {{ [1, 2, 3].reject { |e| e > 2  }.any? }}
                     # ^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `any? {...}` instead of `reject {...}.any?`
          CRYSTAL

        expect_no_corrections source
      end
    end
  end
end
