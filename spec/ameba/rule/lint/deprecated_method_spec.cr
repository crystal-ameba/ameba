require "../../../spec_helper"

describe Ameba::Rule::Lint::DeprecatedMethod do
  subject = Ameba::Rule::Lint::DeprecatedMethod.new

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

  it "autocorrects Time.now to Time.local" do
    expect_correction subject, <<-CRYSTAL
      Time.now
      # ^^^^^^
    CRYSTAL
      Time.local
    CRYSTAL
  end

  it "detects deprecated Time.new" do
    expect_issue subject, <<-CRYSTAL
      Time.new
      # ^^^^^^ error: Call to deprecated method `Time.new` detected: Use Time.local or Time.utc instead
    CRYSTAL
  end

  it "autocorrects Time.new to Time.local" do
    expect_correction subject, <<-CRYSTAL
      Time.new
      # ^^^^^^
    CRYSTAL
      Time.local
    CRYSTAL
  end

  it "detects deprecated URI.escape" do
    expect_issue subject, <<-CRYSTAL
      URI.escape("string")
      # ^^^^^^^^^^^^^^^^^ error: Call to deprecated method `URI.escape` detected: Use URI.encode_www_form or URI.encode_path instead
    CRYSTAL
  end

  it "does not flag non-deprecated methods" do
    expect_no_issues subject, <<-CRYSTAL
      File.open("path")
      Time.local
      Time.utc
      URI.encode_www_form("string")
    CRYSTAL
  end
end
