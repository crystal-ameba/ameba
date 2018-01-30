require "../../spec_helper"

module Ameba::Formatter
  describe DisabledFormatter do
    output = IO::Memory.new
    subject = DisabledFormatter.new output

    describe "#finished" do
      it "writes a final message" do
        subject.finished [Source.new ""]
        output.to_s.should contain "Disabled rules using inline directives:"
      end

      it "writes disabled rules if any" do
        Colorize.enabled = false

        path = "source.cr"
        s = Source.new("", path).tap do |s|
          s.error(ErrorRule.new, 1, 2, "ErrorRule", :disabled)
          s.error(NamedRule.new, 2, 2, "NamedRule", :disabled)
        end
        subject.finished [s]
        log = output.to_s
        log.should contain "#{path}:1 #{ErrorRule.name}"
        log.should contain "#{path}:2 #{NamedRule.name}"
      ensure
        output.clear
        Colorize.enabled = true
      end

      it "does not write not-disabled rules" do
        s = Source.new("", "source.cr").tap do |s|
          s.error(ErrorRule.new, 1, 2, "ErrorRule")
          s.error(NamedRule.new, 2, 2, "NamedRule", :disabled)
        end
        subject.finished [s]
        output.to_s.should_not contain ErrorRule.name
      end
    end
  end
end
