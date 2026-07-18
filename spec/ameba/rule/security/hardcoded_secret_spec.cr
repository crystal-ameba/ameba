require "../../../spec_helper"

module Ameba::Rule::Security
  describe HardcodedSecret do
    subject = HardcodedSecret.new

    it "passes for secrets loaded from the environment" do
      expect_no_issues subject, <<-CRYSTAL
        password = ENV["DB_PASSWORD"]
        api_key = config.api_key
        CRYSTAL
    end

    it "passes for placeholder values" do
      expect_no_issues subject, <<-CRYSTAL
        password = "changeme!"
        api_key = "<your-api-key>"
        CRYSTAL
    end

    it "passes for short values" do
      expect_no_issues subject, <<-CRYSTAL
        password = "test"
        CRYSTAL
    end

    it "passes for non-secret names" do
      expect_no_issues subject, <<-CRYSTAL
        name = "some string value"
        CRYSTAL
    end

    it "reports hardcoded secrets in local variables" do
      expect_issue subject, <<-CRYSTAL
        password = "s3cr3t_p4ssw0rd"
        # ^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Hardcoded secret detected; load it from the environment or a credentials store
        CRYSTAL
    end

    it "reports hardcoded secrets in instance variables" do
      expect_issue subject, <<-CRYSTAL
        @api_key = "abcd1234efgh"
        # ^^^^^^^^^^^^^^^^^^^^^^^ error: Hardcoded secret detected; load it from the environment or a credentials store
        CRYSTAL
    end

    it "reports hardcoded secrets in constants" do
      expect_issue subject, <<-CRYSTAL
        SECRET_KEY = "supersecretvalue1"
        # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Hardcoded secret detected; load it from the environment or a credentials store
        CRYSTAL
    end

    it "passes if source is a spec" do
      expect_no_issues subject, <<-CRYSTAL, "source_spec.cr"
        password = "s3cr3t_p4ssw0rd"
        CRYSTAL
    end
  end
end
