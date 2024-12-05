require "../../spec_helper"

module Ameba::Formatter
  describe DotFormatter do
    describe "#source_finished" do
      it "writes valid source" do
        output = IO::Memory.new
        subject = GitHubCIFormatter.new output

        subject.source_finished Source.new ""
        output.to_s.should eq("")
      end

      it "writes invalid source" do
        output = IO::Memory.new
        subject = GitHubCIFormatter.new output

        s = Source.new "", "/path/to/file.cr"
        loc = Crystal::Location.new("/path/to/file.cr", 0, 0)
        s.add_issue DummyRule.new, loc, loc, "message"

        subject.source_finished s
        output.to_s.should eq("::notice file=/path/to/file.cr,line=0,endLine=0,col=0,endColumn=0,title=Ameba/DummyRule::message\n")
      end
    end
  end
end
