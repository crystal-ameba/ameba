require "../../spec_helper"

# Returns the error raised when compiling a rule with the given *properties*
private def properties_error(properties : String)
  # Temporary files are created next to the spec, not in the system temp directory.
  # Crystal can't require an absolute path, and on the Windows CI runner the temp directory
  # can be on a different drive than the checkout. The files are deleted afterwards.
  file = File.tempfile("rule_config.", ".cr", dir: __DIR__) do |io|
    io.puts <<-CRYSTAL
      require "../../../src/ameba"

      class Ameba::InvalidPropertiesRule < Ameba::Rule::Base
        properties do
          #{properties}
        end
      end
      CRYSTAL
  end

  output = IO::Memory.new
  status = Process.run "crystal", ["build", "--no-codegen", "--no-color", file.path],
    output: output,
    error: output

  status.success?.should be_false

  output.to_s
    .each_line
    .find(&.starts_with?("Error: "))
    .try(&.lchop("Error: "))
ensure
  file.try(&.delete)
end

private def properties_error(properties : Enumerable(String))
  properties_error(properties.join("\n    "))
end

module Ameba
  describe Config::RuleConfig do
    describe ".properties" do
      it "raises if a property has no or many values" do
        properties_error("foo").should eq \
          "Rule properties are expected to be defined as `name value` (optionally followed by `as: Type`), not: `foo`"

        properties_error(%(foo "a", "b")).should eq \
          %(Rule properties are expected to be defined as `name value` (optionally followed by `as: Type`), not: `foo("a", "b")`)
      end

      it "raises if a property is not defined by a call" do
        properties_error("@foo = 1").should eq \
          "Rule properties are expected to be defined as `name value` (optionally followed by `as: Type`), not: `@foo = 1`"
      end

      it "raises on unknown options" do
        properties_error("foo [] of String, type: Array(String)?").should eq \
          "Unknown option `type` of rule property `foo` (expected `as`)"
      end

      it "raises on duplicated properties" do
        properties_error({"foo 1", "foo 2"}).should eq "Rule property `foo` is already defined"
      end

      it "raises on properties configured with the same key" do
        properties_error({"level_1 1", "level1 2"}).should eq \
          "Rule property `level1` would be configured with the same `Level1` key as `level_1`"

        properties_error("excluded_ [] of String").should eq \
          "Rule property `excluded_` would be configured with the same `Excluded` key as `excluded`"
      end

      it "raises on properties overriding existing methods" do
        properties_error(%(name "foo")).should eq \
          "Rule property `name` would override the `name` method of `Ameba::InvalidPropertiesRule`"

        properties_error("special true").should eq \
          "Rule property `special` would override the `special?` method of `Ameba::InvalidPropertiesRule`"
      end
    end
  end
end
