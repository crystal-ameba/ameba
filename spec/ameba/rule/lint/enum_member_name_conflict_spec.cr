require "../../../spec_helper"

module Ameba::Rule::Lint
  describe EnumMemberNameConflict do
    subject = EnumMemberNameConflict.new

    it "passes if there are no enum members with duplicate names" do
      expect_no_issues subject, <<-CRYSTAL
        enum Foo
          Foo
          Bar
          Baz
        end
        CRYSTAL
    end

    it "reports if enum members have their values assigned" do
      expect_issue subject, <<-CRYSTAL
        enum Foo
          Foo = 1
          FOO = 2
        # ^^^ error: Enum member name conflict detected
        end
        CRYSTAL
    end

    it "reports if there are a duplicate enum member names" do
      expect_issue subject, <<-CRYSTAL
        enum Foo
          Foo
          FOo
        # ^^^ error: Enum member name conflict detected
          FoO
        # ^^^ error: Enum member name conflict detected
          FOO
        # ^^^ error: Enum member name conflict detected
        end
        CRYSTAL
    end
  end
end
