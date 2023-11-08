require "../../../spec_helper"

module Ameba::Rule::Documentation
  subject = DocumentationAdmonition.new

  describe DocumentationAdmonition do
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
        expect_issue subject, <<-CRYSTAL
          # #{admonition}: Single-line comment
          # ^{} error: Found a #{admonition} admonition in a comment
          CRYSTAL

        expect_issue subject, <<-CRYSTAL
          # Text before ...
          # #{admonition}(some context): Part of multi-line comment
          # ^{} error: Found a #{admonition} admonition in a comment
          # Text after ...
          CRYSTAL

        expect_issue subject, <<-CRYSTAL
          # #{admonition}
          # ^{} error: Found a #{admonition} admonition in a comment
          if rand > 0.5
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
          expect_issue subject, <<-CRYSTAL
            # #{admonition}(#{past_date}): sth in the past
            # ^{} error: Found a #{admonition} admonition in a comment (21 days past)
            CRYSTAL
        end
      end

      it "fails for admonitions with yesterday's date" do
        subject.admonitions.each do |admonition|
          yesterday_date = (Time.utc - 1.day).to_s(format: "%F")
          expect_issue subject, <<-CRYSTAL
            # #{admonition}(#{yesterday_date}): sth in the past
            # ^{} error: Found a #{admonition} admonition in a comment (1 day past)
            CRYSTAL
        end
      end

      it "fails for admonitions with today's date" do
        subject.admonitions.each do |admonition|
          today_date = Time.utc.to_s(format: "%F")
          expect_issue subject, <<-CRYSTAL
            # #{admonition}(#{today_date}): sth in the past
            # ^{} error: Found a #{admonition} admonition in a comment (today is the day!)
            CRYSTAL
        end
      end

      it "fails for admonitions with invalid date" do
        subject.admonitions.each do |admonition|
          expect_issue subject, <<-CRYSTAL
            # #{admonition}(0000-00-00): sth wrong
            # ^{} error: #{admonition} admonition error: Invalid time: "0000-00-00"
            CRYSTAL
        end
      end
    end

    context "properties" do
      describe "#admonitions" do
        it "lets setting custom admonitions" do
          rule = DocumentationAdmonition.new
          rule.admonitions = %w[FOO BAR]

          rule.admonitions.each do |admonition|
            expect_issue rule, <<-CRYSTAL
              # #{admonition}
              # ^{} error: Found a #{admonition} admonition in a comment
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
