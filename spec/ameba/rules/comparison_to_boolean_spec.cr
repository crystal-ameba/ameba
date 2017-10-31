require "../../spec_helper"

module Ameba::Rules
  subject = ComparisonToBoolean.new

  describe ComparisonToBoolean do
    it "passes if there is no comparison to boolean" do
      source = Source.new %(
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
      )
      subject.catch(source).valid?.should be_true
    end

    context "boolean on the right" do
      it "fails if there is == comparison to boolean" do
        source = Source.new %(
          if s.empty? == true
            :ok
          end
        )
        subject.catch(source).valid?.should be_false
      end

      it "fails if there is != comparison to boolean" do
        source = Source.new %(
          if a != false
            :ok
          end
        )
        subject.catch(source).valid?.should be_false
      end

      it "fails if there is case comparison to boolean" do
        source = Source.new %(
          a === true
        )
        subject.catch(source).valid?.should be_false
      end

      it "reports rule, pos and message" do
        source = Source.new "a != true"
        subject.catch(source)

        error = source.errors.first
        error.rule.should_not be_nil
        error.pos.should eq 1
        error.message.should eq "Comparison to a boolean is pointless"
      end
    end

    context "boolean on the left" do
      it "fails if there is == comparison to boolean" do
        source = Source.new %(
          if true == s.empty?
            :ok
          end
        )
        subject.catch(source).valid?.should be_false
      end

      it "fails if there is != comparison to boolean" do
        source = Source.new %(
          if false != a
            :ok
          end
        )
        subject.catch(source).valid?.should be_false
      end

      it "fails if there is case comparison to boolean" do
        source = Source.new %(
          true === a
        )
        subject.catch(source).valid?.should be_false
      end

      it "reports rule, pos and message" do
        source = Source.new "true != a"
        subject.catch(source)

        error = source.errors.first
        error.rule.should_not be_nil
        error.pos.should eq 1
        error.message.should eq "Comparison to a boolean is pointless"
      end
    end
  end
end
