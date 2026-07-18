require "../../../spec_helper"

module Ameba::Rule::Security
  describe SqlInjection do
    subject = SqlInjection.new

    it "passes for parameterized queries" do
      expect_no_issues subject, <<-CRYSTAL
        db.query("SELECT * FROM users WHERE id = ?", id)
        db.exec("DELETE FROM users WHERE id = $1", id)
        CRYSTAL
    end

    it "passes for non-SQL interpolation" do
      expect_no_issues subject, <<-'CRYSTAL'
        puts "Please update #{name} settings"
        CRYSTAL
    end

    it "passes for interpolation of static literals" do
      expect_no_issues subject, <<-'CRYSTAL'
        db.query("SELECT * FROM #{"users"}")
        CRYSTAL
    end

    it "reports queries built from interpolated strings" do
      expect_issue subject, <<-'CRYSTAL'
        db.query("SELECT * FROM users WHERE id = #{id}")
               # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: SQL statement built from interpolated string can lead to SQL injection
        CRYSTAL
    end

    it "reports SQL strings built from interpolation outside query calls" do
      expect_issue subject, <<-'CRYSTAL'
        sql = "UPDATE users SET name = #{name}"
            # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: SQL statement built from interpolated string can lead to SQL injection
        CRYSTAL
    end

    it "passes if source is a spec" do
      expect_no_issues subject, <<-'CRYSTAL', "source_spec.cr"
        db.query("SELECT * FROM users WHERE id = #{id}")
        CRYSTAL
    end
  end
end
