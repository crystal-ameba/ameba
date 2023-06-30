require "../../../spec_helper"

module Ameba::Rule::Performance
  subject = ExcessiveAllocations.new

  describe ExcessiveAllocations do
    it "passes if there is no potential performance improvements" do
      expect_no_issues subject, <<-CRYSTAL
        "Alice".chars.each(arg) { |c| puts c }
        "Alice".chars(arg).each { |c| puts c }
        "Alice\nBob".lines.each(arg) { |l| puts l }
        "Alice\nBob".lines(arg).each { |l| puts l }
        CRYSTAL
    end

    it "reports if there is a collection method followed by each" do
      source = expect_issue subject, <<-CRYSTAL
        "Alice".chars.each { |c| puts c }
              # ^^^^^^^^^^ error: Use `each_char {...}` instead of `chars.each {...}` to avoid excessive allocation
        "Alice\nBob".lines.each { |l| puts l }
           # ^^^^^^^^^^ error: Use `each_line {...}` instead of `lines.each {...}` to avoid excessive allocation
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        "Alice".each_char { |c| puts c }
        "Alice\nBob".each_line { |l| puts l }
        CRYSTAL
    end

    it "does not report if source is a spec" do
      expect_no_issues subject, <<-CRYSTAL, "source_spec.cr"
        "Alice".chars.each { |c| puts c }
        CRYSTAL
    end

    context "properties" do
      it "#call_names" do
        rule = ExcessiveAllocations.new
        rule.call_names = {
          "children" => "each_child",
        }

        expect_no_issues rule, <<-CRYSTAL
          "Alice".chars.each { |c| puts c }
          CRYSTAL
      end
    end

    context "macro" do
      it "doesn't report in macro scope" do
        expect_no_issues subject, <<-CRYSTAL
          {{ "Alice".chars.each { |c| puts c } }}
          CRYSTAL
      end
    end
  end
end
