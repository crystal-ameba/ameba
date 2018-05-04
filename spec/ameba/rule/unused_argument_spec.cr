require "../../spec_helper"

module Ameba::Rule
  subject = UnusedArgument.new

  describe UnusedArgument do
    it "doesn't report if arguments are used" do
      s = Source.new %(
        def method(a, b, c)
          a + b + c
        end

        3.times do |i|
          i + 1
        end

        ->(i : Int32) { i + 1 }
      )
      subject.catch(s).should be_valid
    end

    it "reports if method argument is unused" do
      s = Source.new %(
        def method(a, b, c)
          a + b
        end
      )
      subject.catch(s).should_not be_valid
      s.errors.first.message.should eq "Unused argument `c`"
    end

    it "reports if block argument is unused" do
      s = Source.new %(
        [1,2].each_with_index do |a, i|
          a
        end
      )
      subject.catch(s).should_not be_valid
      s.errors.first.message.should eq "Unused argument `i`"
    end

    it "reports if proc argument is unused" do
      s = Source.new %(
        -> (a : Int32, b : String) do
          a = a + 1
        end
      )
      subject.catch(s).should_not be_valid
      s.errors.first.message.should eq "Unused argument `b`"
    end

    it "reports multiple unused args" do
      s = Source.new %(
        def method(a, b, c)
          nil
        end
      )
      subject.catch(s).should_not be_valid
      s.errors[0].message.should eq "Unused argument `a`"
      s.errors[1].message.should eq "Unused argument `b`"
      s.errors[2].message.should eq "Unused argument `c`"
    end

    it "doesn't report if it is an instance var argument" do
      s = Source.new %(
        class A
          def method(@name)
          end
        end
      )
      subject.catch(s).should be_valid
    end

    it "doesn't report if a typed argument is used" do
      s = Source.new %(
        def method(x : Int32)
          3.times do
            puts x
          end
        end
      )
      subject.catch(s).should be_valid
    end

    it "doesn't report if an argument with default value is used" do
      s = Source.new %(
        def method(x = 1)
          puts x
        end
      )
      subject.catch(s).should be_valid
    end

    it "doesn't report if argument starts with a _" do
      s = Source.new %(
        def method(_x)
        end
      )
      subject.catch(s).should be_valid
    end

    it "doesn't report if it is a block and used" do
      s = Source.new %(
        def method(&block)
          block.call
        end
      )
      subject.catch(s).should be_valid
    end

    it "doesn't report if it is a used macro argument" do
      s = Source.new %(
        macro my_macro(arg)
          {% arg %}
        end
      )
      subject.catch(s).should be_valid
    end

    it "doesn't report if it is a used macro block argument" do
      s = Source.new %(
        macro my_macro(&block)
          {% block %}
        end
      )
      subject.catch(s).should be_valid
    end

    it "reports if block arg is not used" do
      s = Source.new %(
        def method(&block)
        end
      )
      subject.catch(s).should_not be_valid
    end

    pending "doesn't report if block is used with yield" do
      s = Source.new %(
        def method(&block)
          yield 1
        end
      )
      subject.catch(s).should be_valid
    end

    it "reports rule, location and message" do
      s = Source.new %(
        def method(a)
        end
      ), "source.cr"
      subject.catch(s).should_not be_valid
      error = s.errors.first
      error.rule.should_not be_nil
      error.message.should eq "Unused argument `a`"
      error.location.to_s.should eq "source.cr:2:20"
    end
  end
end
