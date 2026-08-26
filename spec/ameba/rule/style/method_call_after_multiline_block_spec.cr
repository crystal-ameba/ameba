require "../../../spec_helper"

module Ameba::Rule::Style
  describe MethodCallAfterMultilineBlock do
    subject = MethodCallAfterMultilineBlock.new

    it "reports a method call chained after a multi-line do...end block" do
      expect_issue subject, <<-CRYSTAL
        thing do
          # ...
        end.method
          # ^^^^^^ error: Avoid chaining a method call on a do...end block
        CRYSTAL
    end

    it "doesn't report a method call after a single-line do...end block" do
      expect_no_issues subject, <<-CRYSTAL
        thing do :value end.method
        CRYSTAL
    end

    it "doesn't report a method call after a multi-line curly block" do
      expect_no_issues subject, <<-CRYSTAL
        thing {
          :value
        }.method
        CRYSTAL
    end

    it "reports only the call immediately following the block" do
      expect_issue subject, <<-CRYSTAL
        thing do
          :value
        end.first.second
          # ^^^^^ error: Avoid chaining a method call on a do...end block
        CRYSTAL
    end
  end
end
