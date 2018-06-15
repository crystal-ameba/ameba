require "../../../spec_helper"

module Ameba::Rule::Lint
  describe ShadowingOuterLocalVar do
    subject = ShadowingOuterLocalVar.new

    it "doesn't report if there is no shadowing" do
      source = Source.new %(
        def some_method
          foo = 1

          3.times do |bar|
            bar
          end

          -> (baz : Int32) {}

          -> (bar : String) {}
        end
      )

      subject.catch(source).should be_valid
    end

    it "reports if there is a shadowing in a block" do
      source = Source.new %(
        def some_method
          foo = 1

          3.times do |foo|
          end
        end
      )
      subject.catch(source).should_not be_valid
    end

    it "reports if there is a shadowing in a proc" do
      source = Source.new %(
        def some_method
          foo = 1

          -> (foo : Int32) {}
        end
      )
      subject.catch(source).should_not be_valid
    end

    it "reports if there is a shadowing in an inner scope" do
      source = Source.new %(
        def foo
          foo = 1

          3.times do |i|
            3.times { |foo| foo }
          end
        end
      )
      subject.catch(source).should_not be_valid
    end

    it "reports if variable is shadowed twice" do
      source = Source.new %(
        foo = 1

        3.times do |foo|
          -> (foo : Int32) { foo + 1 }
        end
      )
      subject.catch(source).should_not be_valid

      source.issues.size.should eq 2
    end

    it "reports if a splat block argument shadows local var" do
      source = Source.new %(
        foo = 1

        3.times do |*foo|
        end
      )
      subject.catch(source).should_not be_valid
    end

    it "reports if a &block argument is shadowed" do
      source = Source.new %(
        def method_with_block(a, &block)
          3.times do |block|
          end
        end
      )
      subject.catch(source).should_not be_valid
      source.issues.first.message.should eq "Shadowing outer local variable `block`"
    end

    it "reports if there are multiple args and one shadows local var" do
      source = Source.new %(
        foo = 1
        [1, 2, 3].each_with_index do |i, foo|
          i + foo
        end
      )
      subject.catch(source).should_not be_valid
      source.issues.first.message.should eq "Shadowing outer local variable `foo`"
    end

    it "doesn't report if an outer var is reassigned in a block" do
      source = Source.new %(
        def foo
          foo = 1
          3.times do |i|
            foo = 2
          end
        end
      )
      subject.catch(source).should be_valid
    end

    it "doesn't report if an argument is a black hole '_'" do
      source = Source.new %(
        _ = 1
        3.times do |_|
        end
      )
      subject.catch(source).should be_valid
    end

    it "reports rule, location and message" do
      source = Source.new %(
        foo = 1
        3.times { |foo| foo + 1 }
      ), "source.cr"
      subject.catch(source).should_not be_valid

      issue = source.issues.first
      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:3:20"
      issue.message.should eq "Shadowing outer local variable `foo`"
    end
  end
end
