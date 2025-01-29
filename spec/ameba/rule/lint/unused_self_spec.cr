require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = UnusedSelf.new

  describe UnusedSelf do
    it "passes if self is used" do
      expect_no_issues subject, <<-CRYSTAL
        class MyClass
          class_property name : String = "George"

          def self.hello
            puts "hello, #{self.name}!"
          end

          def name : String
            name.self

            self.class.name
          end
        end
        CRYSTAL
    end

    it "fails if self is unused" do
      expect_issue subject, <<-CRYSTAL
        class MyClass
          self
        # ^^^^ error: `self` is not used

          class_property name : String = begin
            self
          # ^^^^ error: `self` is not used

            "George"
          end

          def self.hello
            self
          # ^^^^ error: `self` is not used
            puts "hello, #{self.name}!"
          end
        end
        CRYSTAL
    end
  end
end
