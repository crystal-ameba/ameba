require "../../../spec_helper"

module Ameba::Rule::Performance
  subject = FirstLastAfterFilter.new

  describe FirstLastAfterFilter do
    it "passes if there is no potential performance improvements" do
      expect_no_issues subject, <<-CRYSTAL
        [1, 2, 3].select { |e| e > 1 }
        [1, 2, 3].reverse.select { |e| e > 1 }
        [1, 2, 3].reverse.last
        [1, 2, 3].reverse.first
        [1, 2, 3].reverse.first
        CRYSTAL
    end

    it "reports if there is select followed by last" do
      expect_issue subject, <<-CRYSTAL
        [1, 2, 3].select { |e| e > 2 }.last
                # ^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `reverse_each.find {...}` instead of `select {...}.last`
        CRYSTAL
    end

    it "does not report if source is a spec" do
      expect_no_issues subject, path: "source_spec.cr", code: <<-CRYSTAL
        [1, 2, 3].select { |e| e > 2 }.last
        CRYSTAL
    end

    it "reports if there is select followed by last?" do
      expect_issue subject, <<-CRYSTAL
        [1, 2, 3].select { |e| e > 2 }.last?
                # ^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `reverse_each.find {...}` instead of `select {...}.last?`
        CRYSTAL
    end

    it "reports if there is select followed by first" do
      expect_issue subject, <<-CRYSTAL
        [1, 2, 3].select { |e| e > 2 }.first
                # ^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `find {...}` instead of `select {...}.first`
        CRYSTAL
    end

    it "does not report if there is selected followed by first with arguments" do
      expect_no_issues subject, <<-CRYSTAL
        [1, 2, 3].select { |n| n % 2 == 0 }.first(2)
        CRYSTAL
    end

    it "reports if there is select followed by first?" do
      expect_issue subject, <<-CRYSTAL
        [1, 2, 3].select { |e| e > 2 }.first?
                # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `find {...}` instead of `select {...}.first?`
        CRYSTAL
    end

    it "does not report if there is select followed by any other call" do
      expect_no_issues subject, <<-CRYSTAL
        [1, 2, 3].select { |e| e > 2 }.size
        [1, 2, 3].select { |e| e > 2 }.any?
        CRYSTAL
    end

    context "properties" do
      it "allows to configure object_call_names" do
        rule = FirstLastAfterFilter.new
        rule.filter_names = %w(reject)

        expect_no_issues rule, <<-CRYSTAL
          [1, 2, 3].select { |e| e > 2 }.first
          CRYSTAL
      end
    end

    it "reports rule, pos and message" do
      s = Source.new %(
        [1, 2, 3].select { |e| e > 2 }.first
      ), "source.cr"
      subject.catch(s).should_not be_valid
      s.issues.size.should eq 1

      issue = s.issues.first
      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:1:11"
      issue.end_location.to_s.should eq "source.cr:1:37"

      issue.message.should eq "Use `find {...}` instead of `select {...}.first`"
    end

    context "macro" do
      it "doesn't report in macro scope" do
        expect_no_issues subject, <<-CRYSTAL
          {{ [1, 2, 3].select { |e| e > 2  }.last }}
          CRYSTAL
      end
    end
  end
end
