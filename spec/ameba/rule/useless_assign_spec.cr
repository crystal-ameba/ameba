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

    it "reports a useless assignment in a proc" do
      s = Source.new %(
        ->() {
          a = 2
        }
      )
      subject.catch(s).should_not be_valid
    end

    it "does not report a useless assignment in a block" do
      s = Source.new %(
        def method
          3.times do
            a = 1
          end
        end
      )
      subject.catch(s).should be_valid
    end

    it "reports a useless assignment in a proc inside def" do
      s = Source.new %(
        def method
          ->() {
            a = 2
          }
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "reports a useless assignment in a proc inside a block" do
      s = Source.new %(
        def method
          3.times do
            ->() {
              a = 2
            }
          end
        end
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

    it "passes if assignment used in the inner block scope" do
      s = Source.new %(
        def method
          var = true
          3.times { var = false }
        end
      )
      subject.catch(s).should be_valid
    end

    it "fails if first assignment is useless" do
      s = Source.new %(
        def method
          var = true
          var = false
          var
        end
      )
      subject.catch(s).should_not be_valid
      s.errors.first.location.to_s.should eq ":3:11"
    end

    it "reports if variable reassigned and not used" do
      s = Source.new %(
        def method
          var = true
          var = false
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "passes if variable used in a condition" do
      s = Source.new %(
        def method
          a = 1
          if a
            nil
          end
        end
      )
      subject.catch(s).should be_valid
    end

    it "reports second assignment as useless" do
      s = Source.new %(
        def method
          a = 1
          a = a + 1
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "passes if variable is referenced in other assignment" do
      s = Source.new %(
        def method
          if f = get_something
            @f = f
          end
        end
      )
      subject.catch(s).should be_valid
    end

    it "passes if variable is referenced in a setter" do
      s = Source.new %(
        def method
          foo = 2
          table[foo] ||= "bar"
        end
      )
      subject.catch(s).should be_valid
    end

    it "passes if variable is reassigned but not referenced" do
      s = Source.new %(
        def method
          foo = 1
          puts foo
          foo = 2
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "passes if variable is referenced in a call" do
      s = Source.new %(
        def method
          if f = FORMATTER
            @formatter = f.new
          end
        end
      )
      subject.catch(s).should be_valid
    end

    it "passes if a setter is invoked with operator assignment" do
      s = Source.new %(
        def method
          obj = {} of Symbol => Int32
          obj[:name] = 3
        end
      )
      subject.catch(s).should be_valid
    end

    context "op assigns" do
      it "passes if variable is referenced below the op assign" do
        s = Source.new %(
          def method
            a = 1
            a += 1
            a
          end
        )
        subject.catch(s).should be_valid
      end

      it "passes if variable is referenced in op assign few times" do
        s = Source.new %(
          def method
            a = 1
            a += 1
            a += 1
            a = a + 1
            a
          end
        )
        subject.catch(s).should be_valid
      end

      it "fails if variable is not referenced below the op assign" do
        s = Source.new %(
          def method
            a = 1
            a += 1
          end
        )
        subject.catch(s).should_not be_valid
      end

      it "reports rule, location and a message" do
        s = Source.new %(
          def method
            b = 2
            a = 3
            a += 1
          end
        ), "source.cr"
        subject.catch(s).should_not be_valid

        error = s.errors.last
        error.rule.should_not be_nil
        error.location.to_s.should eq "source.cr:5:13"
        error.message.should eq "Useless assignment to variable `a`"
      end
    end

    context "multi assigns" do
      it "passes if all assigns are referenced" do
        s = Source.new %(
          def method
            a, b = {1, 2}
            a + b
          end
        )
        subject.catch(s).should be_valid
      end

      it "reports if one assign is not referenced" do
        s = Source.new %(
          def method
            a, b = {1, 2}
            a
          end
        )
        subject.catch(s).should_not be_valid
        error = s.errors.first
        error.location.to_s.should eq ":3:16"
        error.message.should eq "Useless assignment to variable `b`"
      end

      it "reports if both assigns are reassigned and useless" do
        s = Source.new %(
          def method
            a, b = {1, 2}
            a, b = {3, 4}
          end
        )
        subject.catch(s).should_not be_valid
      end

      it "reports if both assigns are not referenced" do
        s = Source.new %(
          def method
            a, b = {1, 2}
          end
        )
        subject.catch(s).should_not be_valid

        error = s.errors.first
        error.location.to_s.should eq ":3:13"
        error.message.should eq "Useless assignment to variable `a`"

        error = s.errors.last
        error.location.to_s.should eq ":3:16"
        error.message.should eq "Useless assignment to variable `b`"
      end
    end
  end
end
