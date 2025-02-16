require "../../../spec_helper"

module Ameba::Rule::Lint
  describe DuplicateWhenCondition do
    subject = DuplicateWhenCondition.new

    it "passes if there are no duplicated `when` conditions" do
      expect_no_issues subject, <<-CRYSTAL
        case x
        when .nil?
          do_something
        when Symbol
          do_something_else
        end
        CRYSTAL
    end

    it "reports if there are a duplicated `when` conditions" do
      expect_issue subject, <<-CRYSTAL
        case x
        when .foo?, .nil?
          do_something
        when .nil?
           # ^^^^^ error: Duplicate `when` condition detected
          do_something_else
        end
        CRYSTAL

      expect_issue subject, <<-CRYSTAL
        case
        when foo?
          :foo
        when foo?, bar?
           # ^^^^ error: Duplicate `when` condition detected
           :foobar
        when Time.utc.year == 1996
          :yo
        when Time.utc.year == 1996
           # ^^^^^^^^^^^^^^^^^^^^^ error: Duplicate `when` condition detected
          :yo
        end
        CRYSTAL
    end
  end
end
