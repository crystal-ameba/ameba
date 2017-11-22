require "../../spec_helper"

module Ameba::Rule
  describe DuplicatedWhen do
    subject = DuplicatedWhen.new

    it "passes if there are no duplicated when conditions in the case" do
      s = Source.new %(
        case x
        when "first"
          do_something
        when "second"
          do_something_else
        end

        case x
        when Integer then :one
        when Int32, String then :two
        end

        case {value1, value2}
        when {0, _}
        when {_, 0}
        end

        case x
        when .odd?
        when .even?
        end

        case
        when Integer then :one
        when Integer | String then :two
        end

        case x
        when :one
        when "one"
        end

        case {value1, value2}
        when {String, String}
        end
      )
      subject.catch(s).should be_valid
    end

    it "fails if there is a duplicated when condition in the case" do
      s = Source.new %(
        case x
        when .starts_with?("pattern1")
          do_something1
        when .starts_with?("pattern2")
          do_something2
        when .starts_with?("pattern1")
          do_something3
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "fails if there are multiple when conditions with nil" do
      s = Source.new %(
        case x
        when nil
          say_hello
        when nil
          say_nothing
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "fails if there are multiple whens with is_a? conditions" do
      s = Source.new %(
        case x
        when String then say_hello
        when Integer then say_nothing
        when String then blah
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "fails if there are duplicated whens but in difference order" do
      s = Source.new %(
        case x
        when String, Integer then something
        when Integer then blah
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "fails if there are duplicated conditions in one when" do
      s = Source.new %(
        case x
        when String, String then something
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "reports rule, location and message" do
      s = Source.new %q(
        case x
        when "first"
        when "first"
        end
      ), "source.cr"
      subject.catch(s).should_not be_valid
      error = s.errors.first
      error.rule.should_not be_nil
      error.location.to_s.should eq "source.cr:2:9"
      error.message.should eq "Duplicated when conditions in case"
    end
  end
end
