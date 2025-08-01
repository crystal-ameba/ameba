require "../../../spec_helper"

module Ameba::Rule::Lint
  describe LiteralsComparison do
    subject = LiteralsComparison.new

    it "passes for valid cases" do
      expect_no_issues subject, <<-'CRYSTAL'
        "foo" == foo
        "foo" != foo
        "foo" == FOO
        FOO == "foo"
        foo == "foo"
        foo != "foo"

        {start.year, start.month} == {stop.year, stop.month}
        /foo/ =~ "foo#{bar}"
        /foo/ !~ "foo#{bar}"
        ["foo"] === [bar]
        [foo] === ["bar"]
        [foo] === [bar]
        [foo] == [bar]
        [foo] == [foo]
        CRYSTAL
    end

    it "reports if there is a static comparison evaluating to the same" do
      expect_issue subject, <<-CRYSTAL
        "foo" === "bar"
        # ^^^^^^^^^^^^^ error: Comparison always evaluates to the same
        /foo/ =~ "bar"
        # ^^^^^^^^^^^^ error: Comparison always evaluates to the same
        "foo" <=> "bar"
        # ^^^^^^^^^^^^^ error: Comparison always evaluates to the same
        CRYSTAL
    end

    it "reports if there is a static comparison evaluating to true" do
      expect_issue subject, <<-CRYSTAL
        "foo" == "foo"
        # ^^^^^^^^^^^^ error: Comparison always evaluates to `true`
        "foo" != "bar"
        # ^^^^^^^^^^^^ error: Comparison always evaluates to `true`
        CRYSTAL
    end

    it "reports if there is a static comparison evaluating to false" do
      expect_issue subject, <<-CRYSTAL
        "foo" == "bar"
        # ^^^^^^^^^^^^ error: Comparison always evaluates to `false`
        "foo" != "foo"
        # ^^^^^^^^^^^^ error: Comparison always evaluates to `false`
        CRYSTAL
    end

    context "macro" do
      it "reports in macro scope" do
        expect_issue subject, <<-CRYSTAL
          {{ "foo" == "bar" }}
           # ^^^^^^^^^^^^^^ error: Comparison always evaluates to `false`
          CRYSTAL
      end

      it "passes for valid cases" do
        expect_no_issues subject, <<-CRYSTAL
          {{ "foo" == foo }}
          {{ "foo" != foo }}
          {% foo == "foo" %}
          {% foo != "foo" %}
          CRYSTAL
      end
    end
  end
end
