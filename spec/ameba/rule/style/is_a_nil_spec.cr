require "../../../spec_helper"

module Ameba::Rule::Style
  describe IsANil do
    subject = IsANil.new

    it "doesn't report if there are no is_a?(Nil) calls" do
      expect_no_issues subject, <<-CRYSTAL
        a = 1
        a.nil?
        a.is_a?(NilLiteral)
        a.is_a?(Custom::Nil)
        CRYSTAL
    end

    it "reports if there is a call to is_a?(Nil) without receiver" do
      source = expect_issue subject, <<-CRYSTAL
        a = is_a?(Nil)
                # ^^^ error: Use `nil?` instead of `is_a?(Nil)`
        b = self.is_a?(Nil)
                     # ^^^ error: Use `nil?` instead of `is_a?(Nil)`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        a = self.nil?
        b = self.nil?
        CRYSTAL
    end

    it "reports if there is a call to is_a?(Nil) with receiver" do
      source = expect_issue subject, <<-CRYSTAL
        a.is_a?(Nil)
              # ^^^ error: Use `nil?` instead of `is_a?(Nil)`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        a.nil?
        CRYSTAL
    end

    it "reports if there is a call to is_a?(Nil) within a short block" do
      source = expect_issue subject, <<-CRYSTAL
        [1, nil].reject(&.is_a?(Nil))
                              # ^^^ error: Use `nil?` instead of `is_a?(Nil)`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        [1, nil].reject(&.nil?)
        CRYSTAL
    end

    it "reports and keeps the receiver code intact" do
      source = expect_issue subject, <<-CRYSTAL
        foo(1, # comment
          2).is_a?(Nil)
                 # ^^^ error: Use `nil?` instead of `is_a?(Nil)`
        (a || b).is_a? Nil
                     # ^^^ error: Use `nil?` instead of `is_a?(Nil)`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(1, # comment
          2).nil?
        (a || b).nil?
        CRYSTAL
    end
  end
end
