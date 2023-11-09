require "../../../spec_helper"

module Ameba::Rule::Naming
  subject = Filename.new

  describe Filename do
    it "passes if filename is correct" do
      expect_no_issues subject, code: "", path: "src/foo.cr"
      expect_no_issues subject, code: "", path: "src/foo_bar.cr"
    end

    it "fails if filename is wrong" do
      expect_issue subject, <<-CRYSTAL, path: "src/fooBar.cr"

        # ^{} error: Filename should be underscore-cased: foo_bar.cr, not fooBar.cr
        CRYSTAL
    end
  end
end
