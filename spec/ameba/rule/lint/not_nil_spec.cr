require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = NotNil.new

  describe NotNil do
    it "passes for valid cases" do
      expect_no_issues subject, <<-CRYSTAL
        (1..3).first?.not_nil!(:foo)
        not_nil!
        CRYSTAL
    end

    it "reports if there is a `not_nil!` call" do
      expect_issue subject, <<-CRYSTAL
        (1..3).first?.not_nil!
                    # ^^^^^^^^ error: Avoid using `not_nil!`
        CRYSTAL
    end

    context "macro" do
      it "doesn't report in macro scope" do
        expect_no_issues subject, <<-CRYSTAL
          {{ [1, 2, 3].first.not_nil! }}
          CRYSTAL
      end
    end

    it "reports rule, pos and message" do
      s = Source.new %(
        (1..3).first?.not_nil!
      ), "source.cr"
      subject.catch(s).should_not be_valid
      issue = s.issues.first

      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:1:15"
      issue.end_location.to_s.should eq "source.cr:1:22"
      issue.message.should eq "Avoid using `not_nil!`"
    end
  end
end
