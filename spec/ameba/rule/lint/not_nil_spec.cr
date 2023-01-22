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

    it "reports if there is a `not_nil!` call in the middle of the call-chain" do
      expect_issue subject, <<-CRYSTAL
        (1..3).first?.not_nil!.to_s
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
  end
end
