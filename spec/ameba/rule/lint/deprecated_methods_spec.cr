require "../../spec_helper"

describe Ameba::Rule::Lint::DeprecatedMethods do
  subject = Ameba::Rule::Lint::DeprecatedMethods.new

  it "detects deprecated File.readable?" do
    expect_issue subject, <<-CRYSTAL
      File.readable?("path")
      # ^^^^^^^^^^^^^^^^^^^^ error: Call to deprecated method `File.readable?` detected: Use File::Info#readable? instead
    CRYSTAL
  end

  it "detects deprecated File.writable?" do
    expect_issue subject, <<-CRYSTAL
      File.writable?("path")
      # ^^^^^^^^^^^^^^^^^^^^ error: Call to deprecated method `File.writable?` detected: Use File::Info#writable? instead
    CRYSTAL
  end

  it "detects deprecated File.executable?" do
    expect_issue subject, <<-CRYSTAL
      File.executable?("path")
      # ^^^^^^^^^^^^^^^^^^^^^^ error: Call to deprecated method `File.executable?` detected: Use File::Info#executable? instead
    CRYSTAL
  end

  it "detects deprecated Time.now" do
    expect_issue subject, <<-CRYSTAL
      Time.now
      # ^^^^^^ error: Call to deprecated method `Time.now` detected: Use Time.local or Time.utc instead
    CRYSTAL
  end

  it "does not flag non-deprecated methods" do
    expect_no_issues subject, <<-CRYSTAL
      File.open("path")
      Time.local
      Time.utc
    CRYSTAL
  end
end
