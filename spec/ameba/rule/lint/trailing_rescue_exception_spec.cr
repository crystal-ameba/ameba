require "../../../spec_helper"

module Ameba::Rule::Lint
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
                          # ^^^^^^^^^^^ error: Trailing rescues with a path aren't allowed, use a block rescue instead to filter by exception type
        CRYSTAL
  end
end
