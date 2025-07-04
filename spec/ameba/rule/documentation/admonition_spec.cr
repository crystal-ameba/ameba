require "../../../spec_helper"

module Ameba::Rule::Documentation
  describe Admonition do
    subject = Admonition.new

    it "passes for comments with admonition mid-word/sentence" do
      subject.admonitions.each do |admonition|
        expect_no_issues subject, <<-CRYSTAL
          # Mentioning #{admonition} mid-sentence
          # x#{admonition}x
          # x#{admonition}
          # #{admonition}x
          CRYSTAL
      end
    end

    it "fails for comments with admonition" do
      subject.admonitions.each do |admonition|
        expect_issue subject, <<-CRYSTAL, admonition: admonition
          def foo
            # %{admonition}: Single-line comment
            # ^{admonition} error: Found a %{admonition} admonition in a comment
          end
          CRYSTAL

        expect_issue subject, <<-CRYSTAL, admonition: admonition
          def foo
            # Text before ...
            # %{admonition}(some context): Part of multi-line comment
            # ^{admonition} error: Found a %{admonition} admonition in a comment
            # Text after ...
          end
          CRYSTAL

        expect_issue subject, <<-CRYSTAL, admonition: admonition
          def foo
            # %{admonition}
            # ^{admonition} error: Found a %{admonition} admonition in a comment
            if rand > 0.5
            end
          end
          CRYSTAL
      end
    end

    context "with date" do
      it "passes for admonitions with future date" do
        subject.admonitions.each do |admonition|
          future_date = (Time.utc + 21.days).to_s(format: "%F")
          expect_no_issues subject, <<-CRYSTAL
            # #{admonition}(#{future_date}): sth in the future
            CRYSTAL
        end
      end

      it "fails for admonitions with past date" do
        subject.admonitions.each do |admonition|
          past_date = (Time.utc - 21.days).to_s(format: "%F")
          expect_issue subject, <<-CRYSTAL, admonition: admonition
            # %{admonition}(#{past_date}): sth in the past
            # ^{admonition} error: Found a %{admonition} admonition in a comment (21 days past)
            CRYSTAL
        end
      end

      it "fails for admonitions with yesterday's date" do
        subject.admonitions.each do |admonition|
          yesterday_date = (Time.utc - 1.day).to_s(format: "%F")
          expect_issue subject, <<-CRYSTAL, admonition: admonition
            # %{admonition}(#{yesterday_date}): sth in the past
            # ^{admonition} error: Found a %{admonition} admonition in a comment (1 day past)
            CRYSTAL
        end
      end

      it "fails for admonitions with today's date" do
        subject.admonitions.each do |admonition|
          today_date = Time.utc.to_s(format: "%F")
          expect_issue subject, <<-CRYSTAL, admonition: admonition
            # %{admonition}(#{today_date}): sth in the past
            # ^{admonition} error: Found a %{admonition} admonition in a comment (today is the day!)
            CRYSTAL
        end
      end

      it "fails for admonitions with invalid date" do
        subject.admonitions.each do |admonition|
          expect_issue subject, <<-CRYSTAL, admonition: admonition
            # %{admonition}(0000-00-00): sth wrong
            # ^{admonition} error: %{admonition} admonition error: Invalid time: "0000-00-00"
            CRYSTAL
        end
      end
    end

    context "properties" do
      describe "#admonitions" do
        it "lets setting custom admonitions" do
          rule = Admonition.new
          rule.admonitions = %w[FOO BAR]

          rule.admonitions.each do |admonition|
            expect_issue rule, <<-CRYSTAL, admonition: admonition
              # %{admonition}
              # ^{admonition} error: Found a %{admonition} admonition in a comment
              CRYSTAL
          end

          subject.admonitions.each do |admonition|
            expect_no_issues rule, <<-CRYSTAL
              # #{admonition}
              CRYSTAL
          end
        end
      end
    end
  end
end
