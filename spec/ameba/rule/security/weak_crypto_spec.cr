require "../../../spec_helper"

module Ameba::Rule::Security
  describe WeakCrypto do
    subject = WeakCrypto.new

    it "passes for strong hash algorithms" do
      expect_no_issues subject, <<-CRYSTAL
        Digest::SHA256.hexdigest(data)
        OpenSSL::Digest.new("SHA256")
        CRYSTAL
    end

    it "passes for non-digest paths with matching names" do
      expect_no_issues subject, <<-CRYSTAL
        Foo::MD5.checksum(data)
        CRYSTAL
    end

    it "reports MD5 digest usage" do
      expect_issue subject, <<-CRYSTAL
        Digest::MD5.hexdigest(data)
        # ^^^^^^^^^ error: Weak hash algorithm `MD5` is not suitable for security purposes
        CRYSTAL
    end

    it "reports SHA1 digest usage" do
      expect_issue subject, <<-CRYSTAL
        Digest::SHA1.digest(data)
        # ^^^^^^^^^^ error: Weak hash algorithm `SHA1` is not suitable for security purposes
        CRYSTAL
    end

    it "reports weak OpenSSL digests" do
      expect_issue subject, <<-CRYSTAL
        OpenSSL::Digest.new("md5")
        # ^^^^^^^^^^^^^^^^^^^^^^^^ error: Weak hash algorithm `MD5` is not suitable for security purposes
        CRYSTAL
    end

    it "passes if source is a spec" do
      expect_no_issues subject, <<-CRYSTAL, "source_spec.cr"
        Digest::MD5.hexdigest(data)
        CRYSTAL
    end
  end
end
