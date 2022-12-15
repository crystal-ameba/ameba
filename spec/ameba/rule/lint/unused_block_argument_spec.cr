require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = UnusedBlockArgument.new

  describe UnusedBlockArgument do
    it "doesn't report if it is an instance var argument" do
      s = Source.new %(
        class A
          def initialize(&@callback)
          end
        end
      )
      subject.catch(s).should be_valid
    end

    it "doesn't report if anonymous" do
      s = Source.new %(
        def method(a, b, c, &)
        end
      )
      subject.catch(s).should be_valid
    end

    it "doesn't report if argument name starts with a `_`" do
      s = Source.new %(
        def method(a, b, c, &_block)
        end
      )
      subject.catch(s).should be_valid
    end

    it "doesn't report if it is a block and used" do
      s = Source.new %(
        def method(a, b, c, &block)
          block.call
        end
      )
      subject.catch(s).should be_valid
    end

    it "reports if block arg is not used" do
      s = Source.new %(
        def method(a, b, c, &block)
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "reports if unused and there is yield" do
      s = Source.new %(
        def method(a, b, c, &block)
          3.times do |i|
            i.try do
              yield i
            end
          end
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "doesn't report if anonymous and there is yield" do
      s = Source.new %(
        def method(a, b, c, &)
          yield 1
        end
      )
      subject.catch(s).should be_valid
    end

    it "doesn't report if variable is referenced implicitly" do
      s = Source.new %(
        class Bar < Foo
          def method(a, b, c, &block)
            super
          end
        end
      )
      subject.catch(s).should be_valid
    end

    context "super" do
      it "reports if variable is not referenced implicitly by super" do
        s = Source.new %(
          class Bar < Foo
            def method(a, b, c, &block)
              super a, b, c
            end
          end
        )
        subject.catch(s).should_not be_valid
        s.issues.first.message.should eq "Unused block argument `block`. If it's necessary, " \
                                         "use `_block` as an argument name to indicate " \
                                         "that it won't be used."
      end
    end

    context "macro" do
      it "doesn't report if it is a used macro block argument" do
        s = Source.new %(
          macro my_macro(&block)
            {% block %}
          end
        )
        subject.catch(s).should be_valid
      end
    end
  end
end
