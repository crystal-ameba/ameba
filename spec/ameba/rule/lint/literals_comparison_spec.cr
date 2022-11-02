require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = LiteralsComparison.new

  describe LiteralsComparison do
    it "passes for valid cases" do
      expect_no_issues subject, <<-CRYSTAL
        "foo" == foo
        "foo" != foo
        foo == "foo"
        foo != "foo"
        CRYSTAL
    end

    it "reports if there is a regex comparison possibly evaluating to the same" do
      expect_issue subject, <<-CRYSTAL
        /foo/ === "foo"
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
    end

    it "reports rule, pos and message" do
      s = Source.new %(
        "foo" == "foo"
      ), "source.cr"
      subject.catch(s).should_not be_valid
      issue = s.issues.first

      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:1:1"
      issue.end_location.to_s.should eq "source.cr:1:14"
      issue.message.should eq "Comparison always evaluates to true"
    end
  end
end
