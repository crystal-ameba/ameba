require "../../../spec_helper"

module Ameba::Rule::Performance
  subject = SizeAfterFilter.new

  describe SizeAfterFilter do
    it "passes if there is no potential performance improvements" do
      expect_no_issues subject, <<-CRYSTAL
        [1, 2, 3].select { |e| e > 2 }
        [1, 2, 3].reject { |e| e < 2 }
        [1, 2, 3].count { |e| e > 2 && e.odd? }
        [1, 2, 3].count { |e| e < 2 && e.even? }

        User.select("field AS name").count
        Company.select(:value).count
        CRYSTAL
    end

    it "reports if there is a select followed by size" do
      expect_issue subject, <<-CRYSTAL
        [1, 2, 3].select { |e| e > 2 }.size
                # ^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `count {...}` instead of `select {...}.size`.
        CRYSTAL
    end

    it "does not report if source is a spec" do
      expect_no_issues subject, path: "source_spec.cr", code: <<-CRYSTAL
        [1, 2, 3].select { |e| e > 2 }.size
        CRYSTAL
    end

    it "reports if there is a reject followed by size" do
      expect_issue subject, <<-CRYSTAL
        [1, 2, 3].reject { |e| e < 2 }.size
                # ^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `count {...}` instead of `reject {...}.size`.
        CRYSTAL
    end

    it "reports if a block shorthand used" do
      expect_issue subject, <<-CRYSTAL
        [1, 2, 3].reject(&.empty?).size
                # ^^^^^^^^^^^^^^^^^^^^^ error: Use `count {...}` instead of `reject {...}.size`.
        CRYSTAL
    end

    context "properties" do
      it "#filter_names" do
        rule = SizeAfterFilter.new
        rule.filter_names = %w[select]

        expect_no_issues rule, <<-CRYSTAL
          [1, 2, 3].reject(&.empty?).size
          CRYSTAL
      end
    end

    context "macro" do
      it "doesn't report in macro scope" do
        expect_no_issues subject, <<-CRYSTAL
          {{[1, 2, 3].select { |v| v > 1 }.size}}
          CRYSTAL
      end
    end
  end
end
