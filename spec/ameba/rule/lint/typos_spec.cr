require "../../../spec_helper"

private def check_typos_bin!
  unless Ameba::Rule::Lint::Typos::BIN_PATH
    pending! "`typos` executable is not available"
  end
end

module Ameba::Rule::Lint
  describe Typos do
    subject = Typos.new
    subject.fail_on_error = true

    it "reports typos" do
      check_typos_bin!

      source = expect_issue subject, <<-CRYSTAL
        # method with no arugments
                       # ^^^^^^^^^ error: Typo found: `arugments` -> `arguments`
        def tpos
          # ^^^^ error: Typo found: `tpos` -> `typos`
          :otput
         # ^^^^^ error: Typo found: `otput` -> `output`
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        # method with no arguments
        def typos
          :output
        end
        CRYSTAL
    end
  end
end
