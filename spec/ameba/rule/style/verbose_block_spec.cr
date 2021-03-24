require "../../../spec_helper"

module Ameba::Rule::Style
  subject = VerboseBlock.new

  describe VerboseBlock do
    it "passes if there is no potential performance improvements" do
      source = Source.new %(
        (1..3).any?(&.odd?)
        (1..3).join('.', &.to_s)
        (1..3).each_with_index { |i, idx| i * idx }
        (1..3).map { |i| typeof(i) }
        (1..3).map { |i| i || 0 }
        (1..3).map { |i| :foo }
        (1..3).map { |i| :foo.to_s.split.join('.') }
        (1..3).map { :foo }
      )
      subject.catch(source).should be_valid
    end

    it "passes if the block argument is used within the body" do
      source = Source.new %(
        (1..3).map { |i| i * i }
        (1..3).map { |j| j * j.to_i64 }
        (1..3).map { |k| k.to_i64 * k }
        (1..3).map { |l| l.to_i64 * l.to_i64 }
        (1..3).map { |m| m.to_s[start: m.to_i64, count: 3]? }
        (1..3).map { |n| n.to_s.split.map { |z| n.to_i * z.to_i }.join }
      )
      subject.catch(source).should be_valid
    end

    it "reports if there is a call with a collapsible block" do
      source = Source.new %(
        (1..3).any? { |i| i.odd? }
      )
      subject.catch(source).should_not be_valid
    end

    it "reports if there is a call with an argument + collapsible block" do
      source = Source.new %(
        (1..3).join('.') { |i| i.to_s }
      )
      subject.catch(source).should_not be_valid
    end

    it "reports if there is a call with a collapsible block (with chained call)" do
      source = Source.new %(
        (1..3).map { |i| i.to_s.split.reverse.join.strip }
      )
      subject.catch(source).should_not be_valid
    end

    context "properties" do
      it "#exclude_calls_with_block" do
        source = Source.new %(
          (1..3).in_groups_of(1) { |i| i.map(&.to_s) }
        )
        rule = VerboseBlock.new
        rule
          .tap(&.exclude_calls_with_block = true)
          .catch(source).should be_valid
        rule
          .tap(&.exclude_calls_with_block = false)
          .catch(source).should_not be_valid
      end

      it "#exclude_multiple_line_blocks" do
        source = Source.new %(
          (1..3).any? do |i|
            i.odd?
          end
        )
        rule = VerboseBlock.new
        rule
          .tap(&.exclude_multiple_line_blocks = true)
          .catch(source).should be_valid
        rule
          .tap(&.exclude_multiple_line_blocks = false)
          .catch(source).should_not be_valid
      end

      it "#exclude_prefix_operators" do
        source = Source.new %(
          (1..3).sum { |i| +i }
          (1..3).sum { |i| -i }
          (1..3).sum { |i| ~i }
        )
        rule = VerboseBlock.new
        rule
          .tap(&.exclude_prefix_operators = true)
          .catch(source).should be_valid
        rule
          .tap(&.exclude_prefix_operators = false)
          .tap(&.exclude_operators = false)
          .catch(source).should_not be_valid
      end

      it "#exclude_operators" do
        source = Source.new %(
          (1..3).sum { |i| i * 2 }
        )
        rule = VerboseBlock.new
        rule
          .tap(&.exclude_operators = true)
          .catch(source).should be_valid
        rule
          .tap(&.exclude_operators = false)
          .catch(source).should_not be_valid
      end

      it "#exclude_setters" do
        source = Source.new %(
          Char::Reader.new("abc").tap { |reader| reader.pos = 0 }
        )
        rule = VerboseBlock.new
        rule
          .tap(&.exclude_setters = true)
          .catch(source).should be_valid
        rule
          .tap(&.exclude_setters = false)
          .catch(source).should_not be_valid
      end

      it "#max_line_length" do
        source = Source.new %(
          (1..3).tap &.tap &.tap &.tap &.tap &.tap &.tap do |i|
            i.to_s.reverse.strip.blank?
          end
        )
        rule = VerboseBlock.new
          .tap(&.exclude_multiple_line_blocks = false)
        rule
          .tap(&.max_line_length = 60)
          .catch(source).should be_valid
        rule
          .tap(&.max_line_length = nil)
          .catch(source).should_not be_valid
      end

      it "#max_length" do
        source = Source.new %(
          (1..3).tap { |i| i.to_s.split.reverse.join.strip.blank? }
        )
        rule = VerboseBlock.new
        rule
          .tap(&.max_length = 30)
          .catch(source).should be_valid
        rule
          .tap(&.max_length = nil)
          .catch(source).should_not be_valid
      end
    end

    context "macro" do
      it "reports in macro scope" do
        source = Source.new %(
          {{ (1..3).any? { |i| i.odd? } }}
        )
        subject.catch(source).should_not be_valid
      end
    end

    it "reports call args and named_args" do
      short_block_variants = {
        %|map(&.to_s.[start: 0.to_i64, count: 3]?)|,
        %|map(&.to_s.[0.to_i64, count: 3]?)|,
        %|map(&.to_s.[0.to_i64, 3]?)|,
        %|map(&.to_s.[start: 0.to_i64, count: 3]=("foo"))|,
        %|map(&.to_s.[0.to_i64, count: 3]=("foo"))|,
        %|map(&.to_s.[0.to_i64, 3]=("foo"))|,
        %|map(&.to_s.camelcase(lower: true))|,
        %|map(&.to_s.camelcase)|,
        %|map(&.to_s.gsub('_', '-'))|,
        %|map(&.in?(*{1, 2, 3}, **{foo: :bar}))|,
        %|map(&.in?(1, *foo, 3, **bar))|,
        %|join(separator: '.', &.to_s)|,
      }

      source = Source.new path: "source.cr", code: %(
        (1..3).map { |i| i.to_s[start: 0.to_i64, count: 3]? }
        (1..3).map { |i| i.to_s[0.to_i64, count: 3]? }
        (1..3).map { |i| i.to_s[0.to_i64, 3]? }
        (1..3).map { |i| i.to_s[start: 0.to_i64, count: 3] = "foo" }
        (1..3).map { |i| i.to_s[0.to_i64, count: 3] = "foo" }
        (1..3).map { |i| i.to_s[0.to_i64, 3] = "foo" }
        (1..3).map { |i| i.to_s.camelcase(lower: true) }
        (1..3).map { |i| i.to_s.camelcase }
        (1..3).map { |i| i.to_s.gsub('_', '-') }
        (1..3).map { |i| i.in?(*{1, 2, 3}, **{foo: :bar}) }
        (1..3).map { |i| i.in?(1, *foo, 3, **bar) }
        (1..3).join(separator: '.') { |i| i.to_s }
      )
      rule = VerboseBlock.new
      rule
        .tap(&.exclude_operators = false)
        .catch(source).should_not be_valid
      source.issues.size.should eq(short_block_variants.size)

      source.issues.each_with_index do |issue, i|
        issue.message.should eq(VerboseBlock::MSG % short_block_variants[i])
      end
    end

    it "reports rule, pos and message" do
      source = Source.new path: "source.cr", code: %(
        (1..3).any? { |i| i.odd? }
      )
      subject.catch(source).should_not be_valid
      source.issues.size.should eq 1

      issue = source.issues.first
      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:1:8"
      issue.end_location.to_s.should eq "source.cr:1:26"

      issue.message.should eq "Use short block notation instead: `any?(&.odd?)`"
    end
  end
end
