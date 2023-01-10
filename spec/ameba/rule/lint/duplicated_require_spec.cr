require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = DuplicatedRequire.new

  describe DuplicatedRequire do
    it "passes if there are no duplicated requires" do
      expect_no_issues subject, <<-CRYSTAL
        require "math"
        require "big"
        require "big/big_decimal"
        CRYSTAL
    end

    it "reports if there are a duplicated requires" do
      source = expect_issue subject, <<-CRYSTAL
        require "big"
        require "math"
        require "big"
        # ^^^^^^^^^^^ error: Duplicated require of `big`
        CRYSTAL

      expect_no_corrections source
    end
  end
end
