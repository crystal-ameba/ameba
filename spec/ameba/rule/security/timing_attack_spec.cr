require "../../../spec_helper"

module Ameba::Rule::Security
  describe TimingAttack do
    subject = TimingAttack.new

    it "passes for constant-time comparison" do
      expect_no_issues subject, <<-CRYSTAL
        Crypto::Subtle.constant_time_compare(signature, expected)
        CRYSTAL
    end

    it "passes for comparison of non-digest values" do
      expect_no_issues subject, <<-CRYSTAL
        a == b
        name == "admin"
        CRYSTAL
    end

    it "reports digest comparison with ==" do
      expect_issue subject, <<-CRYSTAL
        signature == OpenSSL::HMAC.hexdigest(:sha256, key, data)
        # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Comparing digests with `==` is vulnerable to timing attacks; use `Crypto::Subtle.constant_time_compare`
        CRYSTAL
    end

    it "reports digest comparison with the digest on the left" do
      expect_issue subject, <<-CRYSTAL
        Digest::SHA256.hexdigest(data) == signature
        # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Comparing digests with `==` is vulnerable to timing attacks; use `Crypto::Subtle.constant_time_compare`
        CRYSTAL
    end

    it "reports digest comparison with !=" do
      expect_issue subject, <<-CRYSTAL
        a != b.digest
        # ^^^^^^^^^^^ error: Comparing digests with `!=` is vulnerable to timing attacks; use `Crypto::Subtle.constant_time_compare`
        CRYSTAL
    end

    it "passes if source is a spec" do
      expect_no_issues subject, <<-CRYSTAL, "source_spec.cr"
        signature == OpenSSL::HMAC.hexdigest(:sha256, key, data)
        CRYSTAL
    end
  end
end
