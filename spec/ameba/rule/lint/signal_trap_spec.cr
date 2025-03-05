require "../../../spec_helper"

module Ameba::Rule::Lint
  describe SignalTrap do
    subject = SignalTrap.new

    it "reports when `Signal::INT/HUP/TERM.trap` is used" do
      source = expect_issue subject, <<-CRYSTAL
        ::Signal::INT.trap { shutdown }
        # ^^^^^^^^^^^^^^^^ error: Use `Process.on_terminate` instead of `::Signal::INT.trap`
        Signal::HUP.trap { shutdown }
        # ^^^^^^^^^^^^^^ error: Use `Process.on_terminate` instead of `Signal::HUP.trap`
        Signal::TERM.trap &shutdown
        # ^^^^^^^^^^^^^^^ error: Use `Process.on_terminate` instead of `Signal::TERM.trap`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        Process.on_terminate { shutdown }
        Process.on_terminate { shutdown }
        Process.on_terminate &shutdown
        CRYSTAL
    end

    it "respects the comment between the path and the call name" do
      source = expect_issue subject, <<-CRYSTAL
        Signal::INT
        # ^^^^^^^^^ error: Use `Process.on_terminate` instead of `Signal::INT.trap`
          # foo
          .trap { shutdown }
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        Process
          # foo
          .on_terminate { shutdown }
        CRYSTAL
    end
  end
end
