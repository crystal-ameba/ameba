require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = SpecFilename.new

  describe SpecFilename do
    it "passes if relative file path does not start with `spec/`" do
      expect_no_issues subject, code: "", path: "src/spec/foo.cr"
      expect_no_issues subject, code: "", path: "src/spec/foo/bar.cr"
    end

    it "passes if file extension is not `.cr`" do
      expect_no_issues subject, code: "", path: "spec/foo.json"
      expect_no_issues subject, code: "", path: "spec/foo/bar.json"
    end

    it "passes if filename is correct" do
      expect_no_issues subject, code: "", path: "spec/foo_spec.cr"
      expect_no_issues subject, code: "", path: "spec/foo/bar_spec.cr"
    end

    it "fails if filename is wrong" do
      expect_issue subject, <<-CRYSTAL, path: "spec/foo.cr"

        # ^{} error: Spec filename should have `_spec` suffix: foo_spec.cr, not foo.cr
        CRYSTAL
    end

    context "properties" do
      context "#ignored_dirs" do
        it "provide sane defaults" do
          expect_no_issues subject, code: "", path: "spec/support/foo.cr"
          expect_no_issues subject, code: "", path: "spec/fixtures/foo.cr"
          expect_no_issues subject, code: "", path: "spec/data/foo.cr"
        end
      end

      context "#ignored_filenames" do
        it "ignores spec_helper by default" do
          expect_no_issues subject, code: "", path: "spec/spec_helper.cr"
          expect_no_issues subject, code: "", path: "spec/foo/spec_helper.cr"
        end
      end
    end
  end
end
