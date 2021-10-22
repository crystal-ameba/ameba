require "../../../spec_helper"

module Ameba::Rule::Performance
  subject = AnyAfterFilter.new

  describe AnyAfterFilter do
    it "passes if there is no potential performance improvements" do
      expect_no_issues subject, %(
        [1, 2, 3].select { |e| e > 1 }.any?(&.zero?)
        [1, 2, 3].reject { |e| e > 1 }.any?(&.zero?)
        [1, 2, 3].select { |e| e > 1 }
        [1, 2, 3].reject { |e| e > 1 }
        [1, 2, 3].any? { |e| e > 1 }
      )
    end

    it "reports if there is select followed by any? without a block" do
      expect_issue subject, %(
        [1, 2, 3].select { |e| e > 2 }.any?
                # ^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `any? {...}` instead of `select {...}.any?`
      )
    end

    it "does not report if source is a spec" do
      expect_no_issues subject, %(
        [1, 2, 3].select { |e| e > 2 }.any?
      ), "source_spec.cr"
    end

    it "reports if there is reject followed by any? without a block" do
      expect_issue subject, %(
        [1, 2, 3].reject { |e| e > 2 }.any?
                # ^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `any? {...}` instead of `reject {...}.any?`
      )
    end

    it "does not report if any? calls contains a block" do
      expect_no_issues subject, %(
        [1, 2, 3].select { |e| e > 2 }.any?(&.zero?)
        [1, 2, 3].reject { |e| e > 2 }.any?(&.zero?)
      )
    end

    context "properties" do
      it "allows to configure object_call_names" do
        rule = Rule::Performance::AnyAfterFilter.new
        rule.filter_names = %w(select)
        expect_no_issues rule, %(
          [1, 2, 3].reject { |e| e > 2 }.any?
        )
      end
    end

    context "macro" do
      it "reports in macro scope" do
        expect_issue subject, %(
          {{ [1, 2, 3].reject { |e| e > 2  }.any? }}
                     # ^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `any? {...}` instead of `reject {...}.any?`
        )
      end
    end

    it "reports rule, pos and message" do
      expect_issue subject, %(
        [1, 2, 3].reject { |e| e > 2 }.any?
                # ^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `any? {...}` instead of `reject {...}.any?`
      )
    end
  end
end
