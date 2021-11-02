require "../../../spec_helper"

module Ameba::Rule::Style
  subject = IsAFilter.new

  describe IsAFilter do
    it "passes if there is no potential performance improvements" do
      expect_no_issues subject, <<-CRYSTAL
        [1, 2, nil].select(Int32)
        [1, 2, nil].reject(Nil)
        CRYSTAL
    end

    it "reports if there is .is_a? call within select" do
      source = expect_issue subject, <<-CRYSTAL
        [1, 2, nil].select(&.is_a?(Int32))
                  # ^^^^^^^^^^^^^^^^^^^^^^ error: Use `select(Int32)` instead of `select {...}`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        [1, 2, nil].select(Int32)
        CRYSTAL
    end

    it "reports if there is .nil? call within reject" do
      source = expect_issue subject, <<-CRYSTAL
        [1, 2, nil].reject(&.nil?)
                  # ^^^^^^^^^^^^^^ error: Use `reject(Nil)` instead of `reject {...}`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        [1, 2, nil].reject(Nil)
        CRYSTAL
    end

    it "does not report if there .is_a? call within block with multiple arguments" do
      expect_no_issues subject, <<-CRYSTAL
        t.all? { |_, v| v.is_a?(String) }
        t.all? { |foo, bar| foo.is_a?(String) }
        t.all? { |foo, bar| bar.is_a?(String) }
        CRYSTAL
    end

    context "properties" do
      it "allows to configure filter_names" do
        rule = IsAFilter.new
        rule.filter_names = %w(select)
        expect_no_issues rule, <<-CRYSTAL
          [1, 2, nil].reject(&.nil?)
          CRYSTAL
      end
    end

    context "macro" do
      it "doesn't report in macro scope" do
        expect_no_issues subject, <<-CRYSTAL
          {{ [1, 2, nil].reject(&.nil?) }}
          CRYSTAL
      end
    end

    it "reports rule, pos and message" do
      source = Source.new path: "source.cr", code: %(
        [1, 2, nil].reject(&.nil?)
      )
      subject.catch(source).should_not be_valid
      source.issues.size.should eq 1

      issue = source.issues.first
      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:1:13"
      issue.end_location.to_s.should eq "source.cr:1:26"

      issue.message.should eq "Use `reject(Nil)` instead of `reject {...}`"
    end
  end
end
