require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = LiteralsComparison.new

  describe LiteralsComparison do
    it "passes for valid cases" do
      expect_no_issues subject, <<-CRYSTAL
        {start.year, start.month} == {stop.year, stop.month}
        ["foo"] === [foo]
        "foo" == foo
        "foo" != foo
        "foo" == FOO
        FOO == "foo"
        foo == "foo"
        foo != "foo"
        CRYSTAL
    end

    it "reports if there is a dynamic comparison possibly evaluating to the same" do
      expect_issue subject, <<-CRYSTAL
        [foo] === [foo]
        # ^^^^^^^^^^^^^ error: Comparison most likely evaluates to the same
        CRYSTAL
    end

    it "reports if there is a static comparison evaluating to the same" do
      expect_issue subject, <<-CRYSTAL
        "foo" === "foo"
        # ^^^^^^^^^^^^^ error: Comparison always evaluates to the same
        CRYSTAL
    end

    it "reports if there is a static comparison evaluating to true (2)" do
      expect_issue subject, <<-CRYSTAL
        "foo" == "foo"
        # ^^^^^^^^^^^^ error: Comparison always evaluates to true
        CRYSTAL
    end

    it "reports if there is a static comparison evaluating to false" do
      expect_issue subject, <<-CRYSTAL
        "foo" != "foo"
        # ^^^^^^^^^^^^ error: Comparison always evaluates to false
        CRYSTAL
    end

    context "macro" do
      it "reports in macro scope" do
        expect_issue subject, <<-CRYSTAL
          {{ "foo" == "foo" }}
           # ^^^^^^^^^^^^^^ error: Comparison always evaluates to true
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
