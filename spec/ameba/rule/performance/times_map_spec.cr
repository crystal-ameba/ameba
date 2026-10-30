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
        Array.new(3) { |i| i * i }
        Array.new(3, &block)
        Array.new(3, &block).select(&.odd?)
        CRYSTAL
    end

    it "reports and corrects short block syntax" do
      source = expect_issue subject, <<-CRYSTAL
        3.times.map(&.to_s).to_a
        # ^^^^^^^^^^^^^^^^^^^^^^ error: Use `Array.new(3) {...}` instead of `3.times.map {...}.to_a`
        3.times.map( &.to_s ).to_a
        # ^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `Array.new(3) {...}` instead of `3.times.map {...}.to_a`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        Array.new(3, &.to_s)
        Array.new(3, &.to_s)
        CRYSTAL
    end

    it "reports and corrects empty argument parentheses followed by a block" do
      source = expect_issue subject, <<-CRYSTAL
        3.times.map() { |i| i * 2 }.to_a
        # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `Array.new(3) {...}` instead of `3.times.map {...}.to_a`
        3.times.map( ) do |i|
        # ^^^^^^^^^^^^^^^^^^^ error: Use `Array.new(3) {...}` instead of `3.times.map {...}.to_a`
          i * 2
        end.to_a
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        Array.new(3) { |i| i * 2 }
        Array.new(3) do |i|
          i * 2
        end
        CRYSTAL
    end

    it "reports and corrects comments within the block" do
      source = expect_issue subject, <<-CRYSTAL
        3.times.map do |i|
        # ^^^^^^^^^^^^^^^^ error: Use `Array.new(3) {...}` instead of `3.times.map {...}.to_a`
          i * 2 # comment
        end.to_a
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        Array.new(3) do |i|
          i * 2 # comment
        end
        CRYSTAL
    end

    it "reports but does not correct comments outside of the block" do
      source = expect_issue subject, <<-CRYSTAL
        3.times.map( # comment
        # ^^^^^^^^^^^^^^^^^^^^ error: Use `Array.new(3) {...}` instead of `3.times.map {...}.to_a`
        ) { |i| i * 2 }.to_a
        3.times
        # ^^^^^ error: Use `Array.new(3) {...}` instead of `3.times.map {...}.to_a`
          .map { |i| i * 2 } # comment
          .to_a
        3.times # comment
        # ^^^^^^^^^^^^^^^ error: Use `Array.new(3) {...}` instead of `3.times.map {...}.to_a`
          .map(&.to_s)
          .to_a
        CRYSTAL

      expect_no_corrections source
    end

    it "reports and corrects parenthesized count expression" do
      source = expect_issue subject, <<-CRYSTAL
        (n + 1 if n).times.map { |i| i * 2 }.to_a
        # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `Array.new((n + 1 if n)) {...}` instead of `(n + 1 if n).times.map {...}.to_a`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        Array.new((n + 1 if n)) { |i| i * 2 }
        CRYSTAL
    end

    it "reports and corrects multi-line count expression" do
      source = expect_issue subject, <<-CRYSTAL
        [
        # ^{} error: Use `Array.new([1, 2].size) {...}` instead of `[1, 2].size.times.map {...}.to_a`
          1, 2,
        ].size.times.map { |i| i * 2 }.to_a
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        Array.new([
          1, 2,
        ].size) { |i| i * 2 }
        CRYSTAL
    end

    it "reports and corrects block arguments" do
      source = expect_issue subject, <<-CRYSTAL
        3.times.map(&block).to_a
        # ^^^^^^^^^^^^^^^^^^^^^^ error: Use `Array.new(3) {...}` instead of `3.times.map {...}.to_a`
        3.times.map(&->(i : Int32) { i * 2 }).to_a
        # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `Array.new(3) {...}` instead of `3.times.map {...}.to_a`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        Array.new(3, &block)
        Array.new(3, &->(i : Int32) { i * 2 })
        CRYSTAL
    end

    it "reports and corrects `to_a` call with parentheses" do
      source = expect_issue subject, <<-CRYSTAL
        3.times.map { |i| i * 2 }.to_a()
        # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `Array.new(3) {...}` instead of `3.times.map {...}.to_a`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        Array.new(3) { |i| i * 2 }
        CRYSTAL
    end

    it "preserves the original formatting of the count expression" do
      source = expect_issue subject, <<-CRYSTAL
        1_000.times.map { |i| i * 2 }.to_a
        # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `Array.new(1_000) {...}` instead of `1_000.times.map {...}.to_a`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        Array.new(1_000) { |i| i * 2 }
        CRYSTAL
    end

    it "does not report calls with arguments" do
      expect_no_issues subject, <<-CRYSTAL
        foo.times(2).map { |i| i * 2 }.to_a
        foo.times(step: 2).map { |i| i * 2 }.to_a
        3.times.map(1) { |i| i * 2 }.to_a
        3.times.map { |i| i * 2 }.to_a(1)
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
