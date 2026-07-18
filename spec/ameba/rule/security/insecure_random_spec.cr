require "../../../spec_helper"

module Ameba::Rule::Security
  describe InsecureRandom do
    subject = InsecureRandom.new

    it "passes for Random::Secure" do
      expect_no_issues subject, <<-CRYSTAL
        Random::Secure.hex(32)
        Random::Secure.urlsafe_base64
        CRYSTAL
    end

    it "passes for non-token randomness" do
      expect_no_issues subject, <<-CRYSTAL
        Random.rand(10)
        Random.new.rand(10)
        bytes.hex
        CRYSTAL
    end

    it "reports token generation with the default generator" do
      expect_issue subject, <<-CRYSTAL
        Random.new.hex(32)
        # ^^^^^^^^^^^^^^^^ error: Use `Random::Secure` to generate security-sensitive values
        CRYSTAL
    end

    it "reports seeded generators" do
      expect_issue subject, <<-CRYSTAL
        Random.new(42).base64(32)
        # ^^^^^^^^^^^^^^^^^^^^^^^ error: Use `Random::Secure` to generate security-sensitive values
        CRYSTAL
    end

    it "passes if source is a spec" do
      expect_no_issues subject, <<-CRYSTAL, "source_spec.cr"
        Random.new.hex(32)
        CRYSTAL
    end
  end
end
