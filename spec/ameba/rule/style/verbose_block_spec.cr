require "../../../spec_helper"

module Ameba::Rule::Style
  subject = VerboseBlock.new

  describe VerboseBlock do
    it "passes if there is no potential performance improvements" do
      expect_no_issues subject, <<-CRYSTAL
        (1..3).any?(&.odd?)
        (1..3).join('.', &.to_s)
        (1..3).each_with_index { |i, idx| i * idx }
        (1..3).map { |i| typeof(i) }
        (1..3).map { |i| i || 0 }
        (1..3).map { |i| :foo }
        (1..3).map { |i| :foo.to_s.split.join('.') }
        (1..3).map { :foo }
        CRYSTAL
    end

    it "passes if the block argument is used within the body" do
      expect_no_issues subject, <<-CRYSTAL
        (1..3).map { |i| i * i }
        (1..3).map { |j| j * j.to_i64 }
        (1..3).map { |k| k.to_i64 * k }
        (1..3).map { |l| l.to_i64 * l.to_i64 }
        (1..3).map { |m| m.to_s[start: m.to_i64, count: 3]? }
        (1..3).map { |n| n.to_s.split.map { |z| n.to_i * z.to_i }.join }
        (1..3).map { |o| o.foo = foos[o.abs]? || 0 }
        CRYSTAL
    end

    it "reports if there is a call with a collapsible block" do
      source = expect_issue subject, <<-CRYSTAL
        (1..3).any? { |i| i.odd? }
             # ^^^^^^^^^^^^^^^^^^^ error: Use short block notation instead: `any?(&.odd?)`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        (1..3).any?(&.odd?)
        CRYSTAL
    end

    it "reports if there is a call with an argument + collapsible block" do
      source = expect_issue subject, <<-CRYSTAL
        (1..3).join('.') { |i| i.to_s }
             # ^^^^^^^^^^^^^^^^^^^^^^^^ error: Use short block notation instead: `join('.', &.to_s)`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        (1..3).join('.', &.to_s)
        CRYSTAL
    end

    it "reports if there is a call with a collapsible block (with chained call)" do
      source = expect_issue subject, <<-CRYSTAL
        (1..3).map { |i| i.to_s.split.reverse.join.strip }
             # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use short block notation instead: `map(&.to_s.split.reverse.join.strip)`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        (1..3).map(&.to_s.split.reverse.join.strip)
        CRYSTAL
    end

    context "properties" do
      it "#exclude_calls_with_block" do
        rule = VerboseBlock.new

        rule.exclude_calls_with_block = true
        expect_no_issues rule, <<-CRYSTAL
          (1..3).in_groups_of(1) { |i| i.map(&.to_s) }
          CRYSTAL

        rule.exclude_calls_with_block = false
        source = expect_issue rule, <<-CRYSTAL
          (1..3).in_groups_of(1) { |i| i.map(&.to_s) }
               # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use short block notation instead: `in_groups_of(1, &.map(&.to_s))`
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          (1..3).in_groups_of(1, &.map(&.to_s))
          CRYSTAL
      end

      it "#exclude_multiple_line_blocks" do
        rule = VerboseBlock.new

        rule.exclude_multiple_line_blocks = true
        expect_no_issues rule, <<-CRYSTAL
          (1..3).any? do |i|
            i.odd?
          end
          CRYSTAL

        rule.exclude_multiple_line_blocks = false
        source = expect_issue rule, <<-CRYSTAL
          (1..3).any? do |i|
               # ^^^^^^^^^^^ error: Use short block notation instead: `any?(&.odd?)`
            i.odd?
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          (1..3).any?(&.odd?)
          CRYSTAL
      end

      it "#exclude_prefix_operators" do
        rule = VerboseBlock.new

        rule.exclude_prefix_operators = true
        expect_no_issues rule, <<-CRYSTAL
          (1..3).sum { |i| +i }
          (1..3).sum { |i| -i }
          (1..3).sum { |i| ~i }
          CRYSTAL

        rule.exclude_prefix_operators = false
        rule.exclude_operators = false
        source = expect_issue rule, <<-CRYSTAL
          (1..3).sum { |i| +i }
               # ^^^^^^^^^^^^^^ error: Use short block notation instead: `sum(&.+)`
          (1..3).sum { |i| -i }
               # ^^^^^^^^^^^^^^ error: Use short block notation instead: `sum(&.-)`
          (1..3).sum { |i| ~i }
               # ^^^^^^^^^^^^^^ error: Use short block notation instead: `sum(&.~)`
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          (1..3).sum(&.+)
          (1..3).sum(&.-)
          (1..3).sum(&.~)
          CRYSTAL
      end

      it "#exclude_operators" do
        rule = VerboseBlock.new

        rule.exclude_operators = true
        expect_no_issues rule, <<-CRYSTAL
          (1..3).sum { |i| i * 2 }
          CRYSTAL

        rule.exclude_operators = false
        source = expect_issue rule, <<-CRYSTAL
          (1..3).sum { |i| i * 2 }
               # ^^^^^^^^^^^^^^^^^ error: Use short block notation instead: `sum(&.*(2))`
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          (1..3).sum(&.*(2))
          CRYSTAL
      end

      it "#exclude_setters" do
        rule = VerboseBlock.new

        rule.exclude_setters = true
        expect_no_issues rule, <<-CRYSTAL
          Char::Reader.new("abc").tap { |reader| reader.pos = 0 }
          CRYSTAL

        rule.exclude_setters = false
        source = expect_issue rule, <<-CRYSTAL
          Char::Reader.new("abc").tap { |reader| reader.pos = 0 }
                                # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use short block notation instead: `tap(&.pos=(0))`
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          Char::Reader.new("abc").tap(&.pos=(0))
          CRYSTAL
      end

      it "#max_line_length" do
        rule = VerboseBlock.new
        rule.exclude_multiple_line_blocks = false

        rule.max_line_length = 60
        expect_no_issues rule, <<-CRYSTAL
          (1..3).tap &.tap &.tap &.tap &.tap &.tap &.tap do |i|
            i.to_s.reverse.strip.blank?
          end
          CRYSTAL

        rule.max_line_length = nil
        source = expect_issue rule, <<-CRYSTAL
          (1..3).tap &.tap &.tap &.tap &.tap &.tap &.tap do |i|
                                                   # ^^^^^^^^^^ error: Use short block notation instead: `tap(&.to_s.reverse.strip.blank?)`
            i.to_s.reverse.strip.blank?
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          (1..3).tap &.tap &.tap &.tap &.tap &.tap &.tap(&.to_s.reverse.strip.blank?)
          CRYSTAL
      end

      it "#max_length" do
        rule = VerboseBlock.new

        rule.max_length = 30
        expect_no_issues rule, <<-CRYSTAL
          (1..3).tap { |i| i.to_s.split.reverse.join.strip.blank? }
          CRYSTAL

        rule.max_length = nil
        source = expect_issue rule, <<-CRYSTAL
          (1..3).tap { |i| i.to_s.split.reverse.join.strip.blank? }
               # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: [...] `tap(&.to_s.split.reverse.join.strip.blank?)`
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          (1..3).tap(&.to_s.split.reverse.join.strip.blank?)
          CRYSTAL
      end
    end

    context "macro" do
      it "reports in macro scope" do
        source = expect_issue subject, <<-CRYSTAL
          {{ (1..3).any? { |i| i.odd? } }}
                  # ^^^^^^^^^^^^^^^^^^^ error: Use short block notation instead: `any?(&.odd?)`
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          {{ (1..3).any?(&.odd?) }}
          CRYSTAL
      end
    end

    it "reports call args and named_args" do
      rule = VerboseBlock.new
      rule.exclude_operators = false

      source = expect_issue rule, <<-CRYSTAL
        (1..3).map { |i| i.to_s[start: 0.to_i64, count: 3]? }
             # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: [...] `map(&.to_s.[start: 0.to_i64, count: 3]?)`
        (1..3).map { |i| i.to_s[0.to_i64, count: 3]? }
             # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: [...] `map(&.to_s.[0.to_i64, count: 3]?)`
        (1..3).map { |i| i.to_s[0.to_i64, 3]? }
             # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: [...] `map(&.to_s.[0.to_i64, 3]?)`
        (1..3).map { |i| i.to_s[start: 0.to_i64, count: 3] = "foo" }
             # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: [...] `map(&.to_s.[start: 0.to_i64, count: 3]=("foo"))`
        (1..3).map { |i| i.to_s[0.to_i64, count: 3] = "foo" }
             # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: [...] `map(&.to_s.[0.to_i64, count: 3]=("foo"))`
        (1..3).map { |i| i.to_s[0.to_i64, 3] = "foo" }
             # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: [...] `map(&.to_s.[0.to_i64, 3]=("foo"))`
        (1..3).map { |i| i.to_s.camelcase(lower: true) }
             # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: [...] `map(&.to_s.camelcase(lower: true))`
        (1..3).map { |i| i.to_s.camelcase }
             # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: [...] `map(&.to_s.camelcase)`
        (1..3).map { |i| i.to_s.gsub('_', '-') }
             # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: [...] `map(&.to_s.gsub('_', '-'))`
        (1..3).map { |i| i.in?(*{1, 2, 3}, **{foo: :bar}) }
             # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: [...] `map(&.in?(*{1, 2, 3}, **{foo: :bar}))`
        (1..3).map { |i| i.in?(1, *foo, 3, **bar) }
             # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: [...] `map(&.in?(1, *foo, 3, **bar))`
        (1..3).join(separator: '.') { |i| i.to_s }
             # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: [...] `join(separator: '.', &.to_s)`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        (1..3).map(&.to_s.[start: 0.to_i64, count: 3]?)
        (1..3).map(&.to_s.[0.to_i64, count: 3]?)
        (1..3).map(&.to_s.[0.to_i64, 3]?)
        (1..3).map(&.to_s.[start: 0.to_i64, count: 3]=("foo"))
        (1..3).map(&.to_s.[0.to_i64, count: 3]=("foo"))
        (1..3).map(&.to_s.[0.to_i64, 3]=("foo"))
        (1..3).map(&.to_s.camelcase(lower: true))
        (1..3).map(&.to_s.camelcase)
        (1..3).map(&.to_s.gsub('_', '-'))
        (1..3).map(&.in?(*{1, 2, 3}, **{foo: :bar}))
        (1..3).map(&.in?(1, *foo, 3, **bar))
        (1..3).join(separator: '.', &.to_s)
        CRYSTAL
    end
  end
end
