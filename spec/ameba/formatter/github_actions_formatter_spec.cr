require "../../spec_helper"

module Ameba::Formatter
  describe GitHubActionsFormatter do
    output = IO::Memory.new
    subject = GitHubActionsFormatter.new(output)

    before_each do
      output.clear
    end

    describe "#source_finished" do
      it "writes valid source" do
        source = Source.new "", "/path/to/file.cr"

        subject.source_finished(source)
        output.to_s.should be_empty
      end

      it "writes invalid source" do
        source = Source.new "", "/path/to/file.cr"
        location = Crystal::Location.new("/path/to/file.cr", 1, 2)

        source.add_issue DummyRule.new, location, location, "message\n2nd line"

        subject.source_finished(source)
        output.to_s.should eq(
          "::notice file=/path/to/file.cr,line=1,col=2,endLine=1,endColumn=2," \
          "title=Ameba/DummyRule::message%0A2nd line\n"
        )
      end
    end

    describe "#finished" do
      it "doesn't do anything if 'GITHUB_STEP_SUMMARY' ENV var is not set" do
        subject.finished [Source.new ""]
        output.to_s.should be_empty
      end

      it "writes a Markdown summary to a filename given in 'GITHUB_STEP_SUMMARY' ENV var" do
        prev_summary = ENV["GITHUB_STEP_SUMMARY"]?
        ENV["GITHUB_STEP_SUMMARY"] = summary_filename = File.tempname
        begin
          sources = [Source.new ""]

          subject.started(sources)
          subject.finished(sources)

          File.exists?(summary_filename).should be_true

          summary = File.read(summary_filename)
          summary.should contain "## Ameba Results :green_heart:"
          summary.should contain "Finished in"
          summary.should contain "**1** sources inspected, **0** failures."
          summary.should contain "> Ameba version: **#{Ameba::VERSION}**"
        ensure
          ENV["GITHUB_STEP_SUMMARY"] = prev_summary
          File.delete(summary_filename) rescue nil
        end
      end

      context "when issues found" do
        it "writes each issue" do
          prev_summary = ENV["GITHUB_STEP_SUMMARY"]?
          ENV["GITHUB_STEP_SUMMARY"] = summary_filename = File.tempname

          repo = ENV["GITHUB_REPOSITORY"]?
          sha = ENV["GITHUB_SHA"]?
          begin
            source = Source.new("", "src/source.cr")
            source.add_issue(DummyRule.new, {1, 1}, {2, 1}, "DummyRuleError")
            source.add_issue(DummyRule.new, {1, 1}, "DummyRuleError 2")
            source.add_issue(NamedRule.new, {1, 2}, "NamedRuleError", status: :disabled)

            subject.finished([source])

            File.exists?(summary_filename).should be_true

            summary = File.read(summary_filename)
            summary.should contain "## Ameba Results :bug:"
            summary.should contain "### Issues found:"
            summary.should contain "#### `src/source.cr` (**2** issues)"
            if repo && sha
              summary.should contain(
                "| [1-2](https://github.com/#{repo}/blob/#{sha}/src/source.cr#L1-L2) " \
                "| Convention | Ameba/DummyRule | DummyRuleError |"
              )
              summary.should contain(
                "| [1](https://github.com/#{repo}/blob/#{sha}/src/source.cr#L1) " \
                "| Convention | Ameba/DummyRule | DummyRuleError 2 |"
              )
            else
              summary.should contain "| 1-2 | Convention | Ameba/DummyRule | DummyRuleError |"
              summary.should contain "| 1 | Convention | Ameba/DummyRule | DummyRuleError 2 |"
            end
            summary.should_not contain "NamedRuleError"
            summary.should contain "**1** sources inspected, **2** failures."
          ensure
            ENV["GITHUB_STEP_SUMMARY"] = prev_summary
            File.delete(summary_filename) rescue nil
          end
        end
      end
    end
  end
end
