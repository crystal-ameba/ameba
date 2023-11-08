require "../../../spec_helper"

module Ameba::Rule::Naming
  subject = QueryBoolMethods.new

  describe QueryBoolMethods do
    it "passes for valid cases" do
      expect_no_issues subject, <<-CRYSTAL
        class Foo
          class_property? foo = true
          property? foo = true
          property foo2 : Bool? = true
          setter panda = true
        end

        module Bar
          class_getter? bar : Bool = true
          getter? bar : Bool
          getter bar2 : Bool? = true
          setter panda : Bool = true

          def initialize(@bar = true)
          end
        end
        CRYSTAL
    end

    it "reports only valid properties" do
      expect_issue subject, <<-CRYSTAL
        class Foo
          class_property? foo = true
          class_property bar = true
                       # ^^^ error: Consider using 'class_property?' for 'bar'
          class_property baz = true
                       # ^^^ error: Consider using 'class_property?' for 'baz'
        end
        CRYSTAL
    end

    {% for call in %w[getter class_getter property class_property] %}
      it "reports `{{ call.id }}` assign with Bool" do
        expect_issue subject, <<-CRYSTAL, call: {{ call }}
          class Foo
            %{call}   foo = true
            _{call} # ^^^ error: Consider using '%{call}?' for 'foo'
          end
          CRYSTAL
      end

      it "reports `{{ call.id }}` type declaration assign with Bool" do
        expect_issue subject, <<-CRYSTAL, call: {{ call }}
          class Foo
            %{call}   foo : Bool = true
            _{call} # ^^^ error: Consider using '%{call}?' for 'foo'
          end
          CRYSTAL
      end

      it "reports `{{ call.id }}` type declaration with Bool" do
        expect_issue subject, <<-CRYSTAL, call: {{ call }}
          class Foo
            %{call}   foo : Bool
            _{call} # ^^^ error: Consider using '%{call}?' for 'foo'

            def initialize(@foo = true)
            end
          end
          CRYSTAL
      end
    {% end %}
  end
end
