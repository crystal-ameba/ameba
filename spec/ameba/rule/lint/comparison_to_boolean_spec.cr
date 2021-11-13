require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = ComparisonToBoolean.new

  describe ComparisonToBoolean do
    it "passes if there is no comparison to boolean" do
      expect_no_issues subject, <<-CRYSTAL
        a = true

        if a
          :ok
        end

        if true
          :ok
        end

        unless s.empty?
          :ok
        end

        :ok if a

        :ok if a != 1

        :ok if a == "true"

        case a
        when true
          :ok
        when false
          :not_ok
        end
        CRYSTAL
    end

    context "boolean on the right" do
      it "fails if there is == comparison to boolean" do
        source = expect_issue subject, <<-CRYSTAL
          if s.empty? == true
           # ^^^^^^^^^^^^^^^^ error: Comparison to a boolean is pointless
            :ok
          end

          if s.empty? == false
           # ^^^^^^^^^^^^^^^^^ error: Comparison to a boolean is pointless
            :ok
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          if s.empty?
            :ok
          end

          if !s.empty?
            :ok
          end
          CRYSTAL
      end

      it "fails if there is != comparison to boolean" do
        source = expect_issue subject, <<-CRYSTAL
          if a != false
           # ^^^^^^^^^^ error: Comparison to a boolean is pointless
            :ok
          end

          if a != true
           # ^^^^^^^^^ error: Comparison to a boolean is pointless
            :ok
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          if a
            :ok
          end

          if !a
            :ok
          end
          CRYSTAL
      end

      it "fails if there is case comparison to boolean" do
        source = expect_issue subject, <<-CRYSTAL
          a === true
          # ^^^^^^^^ error: Comparison to a boolean is pointless
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          a
          CRYSTAL
      end

      it "reports rule, pos and message" do
        source = Source.new "a != true", "source.cr"
        subject.catch(source)

        issue = source.issues.first
        issue.rule.should_not be_nil
        issue.location.to_s.should eq "source.cr:1:1"
        issue.message.should eq "Comparison to a boolean is pointless"
      end
    end

    context "boolean on the left" do
      it "fails if there is == comparison to boolean" do
        source = expect_issue subject, <<-CRYSTAL
          if true == s.empty?
           # ^^^^^^^^^^^^^^^^ error: Comparison to a boolean is pointless
            :ok
          end

          if false == s.empty?
           # ^^^^^^^^^^^^^^^^^ error: Comparison to a boolean is pointless
            :ok
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          if s.empty?
            :ok
          end

          if !s.empty?
            :ok
          end
          CRYSTAL
      end

      it "fails if there is != comparison to boolean" do
        source = expect_issue subject, <<-CRYSTAL
          if false != a
           # ^^^^^^^^^^ error: Comparison to a boolean is pointless
            :ok
          end

          if true != a
           # ^^^^^^^^^ error: Comparison to a boolean is pointless
            :ok
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          if a
            :ok
          end

          if !a
            :ok
          end
          CRYSTAL
      end

      it "fails if there is case comparison to boolean" do
        source = expect_issue subject, <<-CRYSTAL
          true === a
          # ^^^^^^^^ error: Comparison to a boolean is pointless
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          a
          CRYSTAL
      end

      it "reports rule, pos and message" do
        source = Source.new "true != a", "source.cr"
        subject.catch(source).should_not be_valid

        issue = source.issues.first
        issue.rule.should_not be_nil
        issue.location.to_s.should eq "source.cr:1:1"
        issue.end_location.to_s.should eq "source.cr:1:9"
        issue.message.should eq "Comparison to a boolean is pointless"
      end
    end
  end
end
