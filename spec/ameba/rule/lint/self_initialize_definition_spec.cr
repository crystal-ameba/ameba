require "../../../spec_helper"

module Ameba::Rule::Lint
  describe SelfInitializeDefinition do
    subject = SelfInitializeDefinition.new

    {% for keyword in %w[module enum].map(&.id) %}
      context "{{ keyword }}" do
        it "passes for `initialize` method definition with a `self` receiver" do
          expect_no_issues subject, <<-CRYSTAL
            {{ keyword }} Foo
              def self.initialize
              end
            end
            CRYSTAL
        end
      end
    {% end %}

    {% for keyword in %w[struct class].map(&.id) %}
      context "{{ keyword }}" do
        it "passes for `initialize` method definition without a receiver" do
          expect_no_issues subject, <<-CRYSTAL
            {{ keyword }} Foo
              def initialize
              end
            end
            CRYSTAL
        end

        it "passes for `initialize` method definition with an explicit receiver" do
          expect_no_issues subject, <<-CRYSTAL
            {{ keyword }} Foo
            end

            def Foo.initialize
            end
            CRYSTAL
        end

        it "fails for `initialize` method definition with a `self` receiver" do
          source = expect_issue subject, <<-CRYSTAL
            {{ keyword }} Foo
              def self.initialize
            # ^^^^^^^^^^^^^^^^^^^ error: `initialize` method definition should not have a receiver
              end
            end
            CRYSTAL

          expect_correction source, <<-CRYSTAL
            {{ keyword }} Foo
              def initialize
              end
            end
            CRYSTAL
        end
      end
    {% end %}
  end
end
