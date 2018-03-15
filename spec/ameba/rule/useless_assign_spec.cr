require "../../spec_helper"

module Ameba::Rule
  describe UselessAssign do
    subject = UselessAssign.new

    it "passes if there are no useless assigments" do
      s = Source.new %(
        def method
          a = 2
          a
        end
      )
      subject.catch(s).should be_valid
    end

    it "reports a useless assignment in a method" do
      s = Source.new %(
        def method
          a = 2
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "reports a useless assignment in a block" do
      s = Source.new %(
        3.times do
          a = 2
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "reports a useless assignment in a proc" do
      s = Source.new %(
        ->() {
          a = 2
        }
      )
      subject.catch(s).should_not be_valid
    end

    it "reports rule, position and a message" do
      s = Source.new %(
        def method
          a = 2
        end
      ), "source.cr"
      subject.catch(s).should_not be_valid

      error = s.errors.first
      error.rule.should_not be_nil
      error.location.to_s.should eq "source.cr:3:11"
      error.message.should eq "Useless assignment to variable `a`"
    end

    it "does not report useless assignment of instance var" do
      s = Source.new %(
        class Cls
          def initialize(@name)
          end
        end
      )
      subject.catch(s).should be_valid
    end

    it "passes if assignment belongs to outer scope" do
      s = Source.new %(
        def method
          var = true
          3.times { var = false }
          var
        end
      )
      subject.catch(s).should be_valid
    end

    it "reports if there are few assigns one by one" do
      s = Source.new %(
        def method
          a = 2
          a = 2
        end
      )
      subject.catch(s).should_not be_valid
    end
  end
end
