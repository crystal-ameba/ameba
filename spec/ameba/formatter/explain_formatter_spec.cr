require "../../spec_helper"

private LOCATION = {file: "source.cr", line: 1, column: 1}

private def explanation(source)
  Ameba::ErrorRule.new.catch(source)

  output = IO::Memory.new
  Ameba::Formatter::ExplainFormatter.new(output, LOCATION).finished([source])
  output.to_s
end

module Ameba::Formatter
  describe ExplainFormatter do
    describe "#location" do
      it "returns crystal location" do
        location = ExplainFormatter
          .new(STDOUT, {file: "compiler.cr", line: 3, column: 8})
          .location

        location.should be_a Crystal::Location
        location.filename.should eq "compiler.cr"
        location.line_number.should eq 3
        location.column_number.should eq 8
      end
    end

    describe "#output" do
      it "returns io" do
        output = ExplainFormatter
          .new(STDOUT, {file: "compiler.cr", line: 3, column: 8})
          .output

        output.should eq STDOUT
      end
    end

    describe "#finished" do
      it "writes issue info" do
        source = Source.new "a = 42", "source.cr"
        output = explanation(source)
        output.should contain "ISSUE INFO"
        output.should contain "This rule always adds an error"
        output.should contain "source.cr:1:1"
      end

      it "writes affected code" do
        source = Source.new "a = 42", "source.cr"
        output = explanation(source)
        output.should contain "AFFECTED CODE"
        output.should contain "a = 42"
      end

      it "writes rule info" do
        source = Source.new "a = 42", "source.cr"
        output = explanation(source)
        output.should contain "RULE INFO"
        output.should contain "Convention"
        output.should contain "Ameba/ErrorRule"
        output.should contain "Always adds an error at 1:1"
      end

      it "writes detailed description" do
        source = Source.new "a = 42", "source.cr"
        output = explanation(source)
        output.should contain "DETAILED DESCRIPTION"
        output.should contain "Rule extended description"
      end

      it "writes nothing if location not found" do
        source = Source.new "a = 42", "another_source.cr"
        explanation(source).should be_empty
      end
    end
  end
end
