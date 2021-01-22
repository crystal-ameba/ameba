require "../../../spec_helper"

module Ameba::Rule::Performance
  subject = ChainedCallWithNoBang.new

  describe ChainedCallWithNoBang do
    it "passes if there is no potential performance improvements" do
      source = Source.new %(
        (1..3).select { |e| e > 1 }.sort!
        (1..3).select { |e| e > 1 }.sort_by!(&.itself)
        (1..3).select { |e| e > 1 }.uniq!
        (1..3).select { |e| e > 1 }.shuffle!
        (1..3).select { |e| e > 1 }.reverse!
        (1..3).select { |e| e > 1 }.rotate!
      )
      subject.catch(source).should be_valid
    end

    it "reports if there is select followed by reverse" do
      source = Source.new %(
        [1, 2, 3].select { |e| e > 1 }.reverse
      )
      subject.catch(source).should_not be_valid
    end

    it "reports if there is select followed by reverse followed by other call" do
      source = Source.new %(
        [1, 2, 3].select { |e| e > 2 }.reverse.size
      )
      subject.catch(source).should_not be_valid
    end

    context "properties" do
      it "allows to configure `call_names`" do
        source = Source.new %(
          [1, 2, 3].select { |e| e > 2 }.reverse
        )
        rule = ChainedCallWithNoBang.new
        rule.call_names = %w(uniq)
        rule.catch(source).should be_valid
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
      issue.end_location.to_s.should eq "source.cr:1:39"

      issue.message.should eq "Use bang method variant `reverse!` after chained `select` call"
    end

    context "macro" do
      it "doesn't report in macro scope" do
        source = Source.new %(
          {{ [1, 2, 3].select { |e| e > 2  }.reverse }}
        )
        subject.catch(source).should be_valid
      end
    end
  end
end
