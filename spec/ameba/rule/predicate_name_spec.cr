require "../../spec_helper"

module Ameba::Rule
  subject = PredicateName.new

  describe PredicateName do
    it "passes if predicate name is correct" do
      s = Source.new %q(
        def valid?(x)
        end

        class Image
          def picture?(x)
          end
        end

        def allow_this_picture?
        end
      )
      subject.catch(s).should be_valid
    end

    it "fails if predicate name is wrong" do
      s = Source.new %q(
        def is_valid?(x)
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "reports rule, pos and message" do
      s = Source.new %q(
        class Image
          def has_picture?(x)
            true
          end
        end
      ), "source.cr"
      subject.catch(s).should_not be_valid

      error = s.errors.first
      error.rule.should_not be_nil
      error.location.to_s.should eq "source.cr:3:11"
      error.message.should eq(
        "Favour method name 'picture?' over 'has_picture?'")
    end

    it "ignores if alternative name isn't valid syntax" do
      s = Source.new %q(
        class Image
          def is_404?(x)
            true
          end
        end
      )
      subject.catch(s).should be_valid
    end
  end
end
