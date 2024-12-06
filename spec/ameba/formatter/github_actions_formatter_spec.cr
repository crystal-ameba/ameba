require "../../spec_helper"

module Ameba::Formatter
  describe GitHubActionsFormatter do
    describe "#source_finished" do
      it "writes valid source" do
        output = IO::Memory.new
        subject = GitHubActionsFormatter.new(output)

        source = Source.new "", "/path/to/file.cr"

        subject.source_finished(source)
        output.to_s.should be_empty
      end

      it "writes invalid source" do
        output = IO::Memory.new
        subject = GitHubActionsFormatter.new(output)

        source = Source.new "", "/path/to/file.cr"
        location = Crystal::Location.new("/path/to/file.cr", 1, 2)

        source.add_issue DummyRule.new, location, location, "message\n2nd line"

        subject.source_finished(source)
        output.to_s.should eq("::notice file=/path/to/file.cr,line=1,col=2,endLine=1,endColumn=2,title=Ameba/DummyRule::message%0A2nd line\n")
      end
    end
  end
end
