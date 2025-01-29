require "../../../spec_helper"

module Ameba::Rule::Lint
  describe TrailingRescueException do
    subject = TrailingRescueException.new

    it "passes for trailing rescue with literal values" do
      expect_no_issues subject, <<-CRYSTAL
        puts "hello" rescue "world"
        puts :meow rescue 1234
        CRYSTAL
    end

    it "passes for trailing rescue with class initialization" do
      expect_no_issues subject, <<-CRYSTAL
        puts "hello" rescue MyClass.new
        CRYSTAL
    end

    it "fails if trailing rescue has exception name" do
      expect_issue subject, <<-CRYSTAL
        puts "hello" rescue MyException
                          # ^^^^^^^^^^^ error: Use a block variant of `rescue` to filter by the exception type
        CRYSTAL
    end
  end
end
