require "../../../spec_helper"

module Ameba::Rule::Security
  describe CommandInjection do
    subject = CommandInjection.new

    it "passes for commands without interpolation" do
      expect_no_issues subject, <<-CRYSTAL
        system("ls -la")
        `date`
        Process.run("ls", ["-l", path])
        CRYSTAL
    end

    it "passes for interpolation of static literals" do
      expect_no_issues subject, <<-'CRYSTAL'
        system("ls #{"-la"}")
        CRYSTAL
    end

    it "passes when dynamic parts are shell-quoted or safely cast" do
      expect_no_issues subject, <<-'CRYSTAL'
        system("ls -l #{Process.quote(path)}")
        system("kill #{pid.to_i}")
        CRYSTAL
    end

    it "respects MinConfidence" do
      rule = CommandInjection.new
      rule.min_confidence = "High"

      expect_no_issues rule, <<-'CRYSTAL'
        system("ls -l #{path}")
        CRYSTAL

      expect_issue rule, <<-'CRYSTAL'
        system("cat #{env.params.query["file"]}")
        # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Shell command built from interpolated string can lead to command injection
        CRYSTAL
    end

    it "reports system calls with interpolated strings" do
      expect_issue subject, <<-'CRYSTAL'
        system("ls -l #{path}")
        # ^^^^^^^^^^^^^^^^^^^^^ error: Shell command built from interpolated string can lead to command injection
        CRYSTAL
    end

    it "reports backtick commands with interpolated strings" do
      expect_issue subject, <<-'CRYSTAL'
        `cat #{file}`
        # ^^^^^^^^^^^ error: Shell command built from interpolated string can lead to command injection
        CRYSTAL
    end

    it "passes if source is a spec" do
      expect_no_issues subject, <<-'CRYSTAL', "source_spec.cr"
        system("ls -l #{path}")
        CRYSTAL
    end
  end
end
