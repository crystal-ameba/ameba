require "../../../spec_helper"

module Ameba::Rule::Style
  describe PercentLiteralDelimiters do
    subject = PercentLiteralDelimiters.new

    it "passes if percent literal delimiters are written correctly" do
      expect_no_issues subject, <<-CRYSTAL
        %(one two three)
        %w[one two three]
        %i[one two three]
        %r{one(two )?three[!]}
        CRYSTAL
    end

    it "fails if percent literal delimiters are written incorrectly" do
      expect_issue subject, <<-CRYSTAL
        %[one two three]
        # ^{} error: `%`-literals should be delimited by `(` and `)`
        %w(one two three)
        # ^{} error: `%w`-literals should be delimited by `[` and `]`
        %i(one two three)
        # ^{} error: `%i`-literals should be delimited by `[` and `]`
        %r|one two three|
        # ^{} error: `%r`-literals should be delimited by `{` and `}`
        CRYSTAL
    end

    it "corrects incorrect percent literal delimiters" do
      source = expect_issue subject, <<-CRYSTAL
        %[[] () {}]
        # ^{} error: `%`-literals should be delimited by `(` and `)`
        %w(
        # ^{} error: `%w`-literals should be delimited by `[` and `]`
          one two three
        )
        %i(
        # ^{} error: `%i`-literals should be delimited by `[` and `]`
          one
          two
          three
        )
        %r|one(two )?three[!]|
        # ^{} error: `%r`-literals should be delimited by `{` and `}`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        %([] () {})
        %w[
          one two three
        ]
        %i[
          one
          two
          three
        ]
        %r{one(two )?three[!]}
        CRYSTAL
    end

    it "reports rule, location and message" do
      expect_issue subject, <<-CRYSTAL
        def foo
          %[one two three]
        # ^ error: `%`-literals should be delimited by `(` and `)`
          %w(one two three)
        # ^^ error: `%w`-literals should be delimited by `[` and `]`
        end
        CRYSTAL
    end

    context "properties" do
      context "#default_delimiters" do
        it "allows setting custom values" do
          rule = PercentLiteralDelimiters.new
          rule.default_delimiters = "||"
          rule.preferred_delimiters = {
            "%w" => "{}",
          } of String => String?

          expect_no_issues rule, <<-CRYSTAL
            %w{one two three}
            %i|one two three|
            CRYSTAL
        end

        it "allows ignoring default delimiters by setting them to `nil`" do
          rule = PercentLiteralDelimiters.new
          rule.default_delimiters = nil
          rule.preferred_delimiters = {
            "%Q" => "{}",
          } of String => String?

          expect_no_issues rule, <<-CRYSTAL
            %w(one two three)
            %i|one two three|
            %r<foo(bar)?>
            CRYSTAL

          expect_issue rule, <<-CRYSTAL
            %Q[one two three]
            # ^{} error: `%Q`-literals should be delimited by `{` and `}`
            CRYSTAL
        end
      end

      context "#preferred_delimiters" do
        it "allows setting custom values" do
          rule = PercentLiteralDelimiters.new
          rule.preferred_delimiters = {
            "%w" => "()",
            "%i" => "||",
          } of String => String?

          expect_no_issues rule, <<-CRYSTAL
            %w(one two three)
            %i|one two three|
            CRYSTAL
        end

        it "allows ignoring certain delimiters by setting them to `nil`" do
          rule = PercentLiteralDelimiters.new
          rule.preferred_delimiters["%r"] = nil

          expect_no_issues rule, <<-CRYSTAL
            %r[foo(bar)?]
            %r{foo(bar)?}
            %r<foo(bar)?>
            CRYSTAL
        end
      end

      context "#ignore_literals_containing_delimiters?" do
        it "ignores different delimiters if enabled" do
          rule = PercentLiteralDelimiters.new
          rule.ignore_literals_containing_delimiters = true

          expect_issue rule, <<-CRYSTAL
            %[one two three]
            # ^{} error: `%`-literals should be delimited by `(` and `)`
            %w(one two three)
            # ^{} error: `%w`-literals should be delimited by `[` and `]`
            %i(one two three)
            # ^{} error: `%i`-literals should be delimited by `[` and `]`
            %r<foo[o]>
            # ^{} error: `%r`-literals should be delimited by `{` and `}`
            CRYSTAL

          expect_no_issues rule, <<-CRYSTAL
            %[one (two) three]
            %w([] []?)
            %i([] []?)
            %r<foo[o]{1,3}>
            CRYSTAL
        end

        it "ignores different delimiters if disabled" do
          rule = PercentLiteralDelimiters.new
          rule.ignore_literals_containing_delimiters = false

          expect_issue rule, <<-CRYSTAL
            %[(one two three)]
            # ^{} error: `%`-literals should be delimited by `(` and `)`
            %w([] []?)
            # ^{} error: `%w`-literals should be delimited by `[` and `]`
            %i([] []?)
            # ^{} error: `%i`-literals should be delimited by `[` and `]`
            %r<foo[o]{1,3}>
            # ^{} error: `%r`-literals should be delimited by `{` and `}`
            CRYSTAL
        end
      end
    end
  end
end
