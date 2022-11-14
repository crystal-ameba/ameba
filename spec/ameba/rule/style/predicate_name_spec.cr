require "../../../spec_helper"

module Ameba::Rule::Style
  subject = PredicateName.new

  describe PredicateName do
    it "passes if predicate name is correct" do
      expect_no_issues subject, <<-CRYSTAL
        def valid?(x)
        end

        class Image
          def picture?(x)
          end
        end

        def allow_this_picture?
        end
        CRYSTAL
    end

    it "fails if predicate name is wrong" do
      expect_issue subject, <<-CRYSTAL
        def is_valid?(x)
        # ^^^^^^^^^^^^^^ error: Favour method name 'valid?' over 'is_valid?'
        end
        CRYSTAL
    end

    it "reports rule, pos and message" do
      s = Source.new %q(
        class Image
          def is_valid?(x)
            true
          end
        end
      ), "source.cr"
      subject.catch(s).should_not be_valid

      issue = s.issues.first
      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:2:3"
      issue.end_location.to_s.should eq "source.cr:4:5"
      issue.message.should eq(
        "Favour method name 'valid?' over 'is_valid?'")
    end

    it "ignores if alternative name isn't valid syntax" do
      expect_no_issues subject, <<-CRYSTAL
        class Image
          def is_404?(x)
            true
          end
        end
        CRYSTAL
    end
  end
end
