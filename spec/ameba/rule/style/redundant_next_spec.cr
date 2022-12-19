require "../../../spec_helper"

module Ameba::Rule::Style
  subject = RedundantNext.new

  describe RedundantNext do
    it "does not report if there is no redundant next" do
      expect_no_issues subject, <<-CRYSTAL
        array.map { |x| x + 1 }
        CRYSTAL
    end

    it "reports if there is redundant next with argument in the block" do
      source = expect_issue subject, <<-CRYSTAL
        block do |v|
          next v + 1
        # ^^^^^^^^^^ error: Redundant `next` detected
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        block do |v|
          v + 1
        end
        CRYSTAL
    end

    context "if" do
      it "doesn't report if there is not redundant next in if branch" do
        expect_no_issues subject, <<-CRYSTAL
          block do |v|
            next if v > 10
          end
          CRYSTAL
      end

      it "reports if there is redundant next in if/else branch" do
        source = expect_issue subject, <<-CRYSTAL
          block do |a|
            if a > 0
              next a + 1
            # ^^^^^^^^^^ error: Redundant `next` detected
            else
              next a + 2
            # ^^^^^^^^^^ error: Redundant `next` detected
            end
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          block do |a|
            if a > 0
              a + 1
            else
              a + 2
            end
          end
          CRYSTAL
      end
    end

    context "unless" do
      it "doesn't report if there is no redundant next in unless branch" do
        expect_no_issues subject, <<-CRYSTAL
          block do |v|
            next unless v > 10
          end
          CRYSTAL
      end

      it "reports if there is redundant next in unless/else branch" do
        source = expect_issue subject, <<-CRYSTAL
          block do |a|
            unless a > 0
              next a + 1
            # ^^^^^^^^^^ error: Redundant `next` detected
            else
              next a + 2
            # ^^^^^^^^^^ error: Redundant `next` detected
            end
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          block do |a|
            unless a > 0
              a + 1
            else
              a + 2
            end
          end
          CRYSTAL
      end
    end

    context "expressions" do
      it "doesn't report if there is no redundant next in expressions" do
        expect_no_issues subject, <<-CRYSTAL
          block do |v|
            a = 1
            a + v
          end
          CRYSTAL
      end

      it "reports if there is redundant next in expressions" do
        source = expect_issue subject, <<-CRYSTAL
          block do |a|
            a = 1
            next a
          # ^^^^^^ error: Redundant `next` detected
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          block do |a|
            a = 1
            a
          end
          CRYSTAL
      end
    end

    context "binary-op" do
      it "doesn't report if there is no redundant next in binary op" do
        expect_no_issues subject, <<-CRYSTAL
          block do |v|
            a && v
          end
          CRYSTAL
      end

      it "reports if there is redundant next in binary op" do
        source = expect_issue subject, <<-CRYSTAL
          block do |a|
            a && next a
               # ^^^^^^ error: Redundant `next` detected
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          block do |a|
            a && a
          end
          CRYSTAL
      end
    end

    context "exception handler" do
      it "doesn't report if there is no redundant next in exception handler" do
        expect_no_issues subject, <<-CRYSTAL
          block do |v|
            v + 1
          rescue e
            next v if v > 0
          end
          CRYSTAL
      end

      it "reports if there is redundant next in exception handler" do
        source = expect_issue subject, <<-CRYSTAL
          block do |a|
            next a + 1
          # ^^^^^^^^^^ error: Redundant `next` detected
          rescue ArgumentError
            next a + 2
          # ^^^^^^^^^^ error: Redundant `next` detected
          rescue Exception
            a + 2
            next a
          # ^^^^^^ error: Redundant `next` detected
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          block do |a|
            a + 1
          rescue ArgumentError
            a + 2
          rescue Exception
            a + 2
            a
          end
          CRYSTAL
      end
    end

    it "reports correct rule, error message and position" do
      s = Source.new %(
        block do |v|
          next v + 1
        end
      ), "source.cr"
      subject.catch(s).should_not be_valid
      s.issues.size.should eq 1
      issue = s.issues.first
      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:2:3"
      issue.end_location.to_s.should eq "source.cr:2:12"
      issue.message.should eq "Redundant `next` detected"
    end

    context "properties" do
      context "#allow_multi_next" do
        it "allows multi next statements by default" do
          expect_no_issues subject, <<-CRYSTAL
            block do |a, b|
              next a, b
            end
            CRYSTAL
        end

        it "allows to configure multi next statements" do
          rule = RedundantNext.new
          rule.allow_multi_next = false
          source = expect_issue rule, <<-CRYSTAL
            block do |a, b|
              next a, b
            # ^^^^^^^^^ error: Redundant `next` detected
            end
            CRYSTAL

          expect_correction source, <<-CRYSTAL
            block do |a, b|
              {a, b}
            end
            CRYSTAL
        end
      end

      context "#allow_empty_next" do
        it "allows empty next statements by default" do
          expect_no_issues subject, <<-CRYSTAL
            block do
              next
            end
            CRYSTAL
        end

        it "allows to configure empty next statements" do
          rule = RedundantNext.new
          rule.allow_empty_next = false
          source = expect_issue rule, <<-CRYSTAL
            block do
              next
            # ^^^^ error: Redundant `next` detected
            end
            CRYSTAL

          expect_no_corrections source
        end
      end
    end
  end
end
