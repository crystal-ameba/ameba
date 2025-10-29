require "../../../spec_helper"

module Ameba::Rule::Performance
  describe TimesMap do
    subject = TimesMap.new

    it "passes if there is no potential performance improvements" do
      expect_no_issues subject, <<-CRYSTAL
        3.times.map { |i| i * i }.to_a { |i| i * -1 }
        3.times.map { |i| i * i }
        3.times { |i| i * i }
        CRYSTAL
    end

    it "reports if there is map followed by flatten call" do
      source = expect_issue subject, <<-CRYSTAL
        foo.bar.times.map do |i|
        # ^^^^^^^^^^^^^^^^^^^^^^ error: Use `Array.new(foo.bar) {...}` instead of `foo.bar.times.map {...}.to_a`
          i * i
        end.to_a
        3.times.map { |i| i * i }.to_a
        # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `Array.new(3) {...}` instead of `3.times.map {...}.to_a`
        3.times.map(&block).to_a
        # ^^^^^^^^^^^^^^^^^^^^^^ error: Use `Array.new(3) {...}` instead of `3.times.map {...}.to_a`
        3.times.map(&block).to_a.select(&.odd?)
        # ^^^^^^^^^^^^^^^^^^^^^^ error: Use `Array.new(3) {...}` instead of `3.times.map {...}.to_a`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        Array.new(foo.bar) do |i|
          i * i
        end
        Array.new(3) do |i| i * i end
        Array.new(3, &block)
        Array.new(3, &block).select(&.odd?)
        CRYSTAL
    end

    it "does not report is source is a spec" do
      expect_no_issues subject, path: "source_spec.cr", code: <<-CRYSTAL
        3.times.map { |i| i * i }.to_a
        CRYSTAL
    end

    context "macro" do
      it "doesn't report in macro scope" do
        expect_no_issues subject, <<-CRYSTAL
          {{ 3.times.map { |i| i * i }.to_a }}
          CRYSTAL
      end
    end
  end
end
