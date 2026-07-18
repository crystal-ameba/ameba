require "../../../spec_helper"

module Ameba::Rule::Security
  describe NoTlsVerify do
    subject = NoTlsVerify.new

    it "passes for peer verification" do
      expect_no_issues subject, <<-CRYSTAL
        context.verify_mode = OpenSSL::SSL::VerifyMode::PEER
        CRYSTAL
    end

    it "reports disabled certificate verification" do
      expect_issue subject, <<-CRYSTAL
        context.verify_mode = OpenSSL::SSL::VerifyMode::NONE
                            # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Disabling TLS certificate verification exposes the connection to man-in-the-middle attacks
        CRYSTAL
    end

    it "reports the short path form" do
      expect_issue subject, <<-CRYSTAL
        VerifyMode::NONE
        # ^^^^^^^^^^^^^^ error: Disabling TLS certificate verification exposes the connection to man-in-the-middle attacks
        CRYSTAL
    end

    it "passes if source is a spec" do
      expect_no_issues subject, <<-CRYSTAL, "source_spec.cr"
        context.verify_mode = OpenSSL::SSL::VerifyMode::NONE
        CRYSTAL
    end
  end
end
