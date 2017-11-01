require "../../spec_helper"

module Ameba::Rules
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
      )
      subject.catch(s).valid?.should be_true
    end

    it "fails if predicate name is wrong" do
      s = Source.new %q(
        def is_valid?(x)
        end
      )
      subject.catch(s).valid?.should be_false
    end

    it "reports rule, pos and message" do
      s = Source.new %q(
        class Image
          def has_picture?(x)
            true
          end
        end
      )
      subject.catch(s).valid?.should be_false

      error = s.errors.first
      error.rule.should_not be_nil
      error.pos.should eq 3
      error.message.should eq(
        "Favour method name 'picture?' over 'has_picture?'")
    end
  end
end
