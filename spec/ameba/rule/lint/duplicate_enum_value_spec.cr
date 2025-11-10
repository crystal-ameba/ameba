require "../../../spec_helper"

module Ameba::Rule::Lint
  describe DuplicateEnumValue do
    subject = DuplicateEnumValue.new

    it "passes if there are no enum members with duplicate values" do
      expect_no_issues subject, <<-CRYSTAL
        enum Foo
          Foo
          Bar
          Baz
        end
        CRYSTAL
    end

    it "passes if there are no duplicate enum member values" do
      expect_no_issues subject, <<-CRYSTAL
        enum Foo
          Foo = 1
          Bar = 2
          Baz = 3
        end
        CRYSTAL
    end

    it "passes if there are aliased enum member values" do
      expect_no_issues subject, <<-CRYSTAL
        enum Foo
          Foo = 1
          Bar = 2
          Baz = Bar
        end
        CRYSTAL
    end

    it "reports if there are a duplicate enum member values" do
      expect_issue subject, <<-CRYSTAL
        enum Foo
          Foo = 111
          Bar = 222
          Baz = 222
              # ^^^ error: Duplicate enum member value detected
          Bat = 222
              # ^^^ error: Duplicate enum member value detected
        end
        CRYSTAL
    end
  end
end
