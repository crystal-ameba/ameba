require "../../../spec_helper"

module Ameba::Rule::Performance
  subject = ChainedCallWithNoBang.new

  describe ChainedCallWithNoBang do
    it "passes if there is no potential performance improvements" do
      expect_no_issues subject, <<-CRYSTAL
        (1..3).select { |e| e > 1 }.sort!
        (1..3).select { |e| e > 1 }.sort_by!(&.itself)
        (1..3).select { |e| e > 1 }.uniq!
        (1..3).select { |e| e > 1 }.shuffle!
        (1..3).select { |e| e > 1 }.reverse!
        (1..3).select { |e| e > 1 }.rotate!
        CRYSTAL
    end

    it "reports if there is select followed by reverse" do
      source = expect_issue subject, <<-CRYSTAL
        [1, 2, 3].select { |e| e > 1 }.reverse
                                     # ^^^^^^^ error: Use bang method variant `reverse!` after chained `select` call
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        [1, 2, 3].select { |e| e > 1 }.reverse!
        CRYSTAL
    end

    it "does not report if source is a spec" do
      expect_no_issues subject, <<-CRYSTAL, "source_spec.cr"
        [1, 2, 3].select { |e| e > 1 }.reverse
        CRYSTAL
    end

    it "reports if there is select followed by reverse followed by other call" do
      source = expect_issue subject, <<-CRYSTAL
        [1, 2, 3].select { |e| e > 2 }.reverse.size
                                     # ^^^^^^^ error: Use bang method variant `reverse!` after chained `select` call
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        [1, 2, 3].select { |e| e > 2 }.reverse!.size
        CRYSTAL
    end

    context "properties" do
      it "allows to configure `call_names`" do
        rule = ChainedCallWithNoBang.new
        rule.call_names = %w(uniq)
        expect_no_issues rule, <<-CRYSTAL
          [1, 2, 3].select { |e| e > 2 }.reverse
          CRYSTAL
      end
    end

    it "reports rule, pos and message" do
      source = Source.new path: "source.cr", code: <<-CODE
        [1, 2, 3].select { |e| e > 1 }.reverse
        CODE

      subject.catch(source).should_not be_valid
      source.issues.size.should eq 1

      issue = source.issues.first
      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:1:32"
      issue.end_location.to_s.should eq "source.cr:1:38"

      issue.message.should eq "Use bang method variant `reverse!` after chained `select` call"
    end

    context "macro" do
      it "doesn't report in macro scope" do
        expect_no_issues subject, <<-CRYSTAL
          {{ [1, 2, 3].select { |e| e > 2  }.reverse }}
          CRYSTAL
      end
    end
  end
end
