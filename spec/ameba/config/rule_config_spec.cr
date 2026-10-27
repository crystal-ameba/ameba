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

# Returns the rule loaded from the given *yaml* config
private def load_rule(yaml : String)
  Ameba::ConfigRule.new(YAML.parse(yaml))
end

module Ameba
  class ConfigRule < Rule::Base
    @[Flags]
    enum Option
      Foo
      Bar
    end

    properties do
      description "Rule to test loading its properties from YAML"
      count 1
      limit 2, as: Int32?
      prefix "x"
      strict false
      names %w[a]
      options :foo, as: Option
      severities({Severity::Error => 1})
      pair({"a", 1})
      record({a: 1, b: nil}, as: NamedTuple(a: Int32, b: String?))
      either "a", as: String | Array(String)
    end
  end

  class ConfigSeverityRule < Rule::Base
    properties do
      description "Rule to test loading its severity from YAML"
      severity :warning
    end
  end

  describe Config::RuleConfig do
    describe ".new" do
      it "uses the defaults if the rule isn't configured" do
        {ConfigRule.new, load_rule("Ameba/OtherRule: {}")}.each do |rule|
          rule.count.should eq 1
          rule.limit.should eq 2
          rule.prefix.should eq "x"
          rule.strict?.should be_false
          rule.names.should eq %w[a]
          rule.options.should eq ConfigRule::Option::Foo
          rule.severities.should eq({Severity::Error => 1})
          rule.pair.should eq({"a", 1})
          rule.record.should eq({a: 1, b: nil})
          rule.either.should eq "a"

          rule.enabled?.should be_true
          rule.severity.should eq Severity::Convention
          rule.excluded.should be_nil
          rule.since_version.should be_nil
        end
      end

      it "loads properties by their camelcased keys" do
        rule = load_rule <<-YAML
          Ameba/ConfigRule:
            Count: 2
            Prefix: y
            Strict: true
            Names: [b, c]
          YAML

        rule.count.should eq 2
        rule.prefix.should eq "y"
        rule.strict?.should be_true
        rule.names.should eq %w[b c]
      end

      it "keeps the defaults of the properties left out" do
        rule = load_rule <<-YAML
          Ameba/ConfigRule:
            Count: 2
          YAML

        rule.count.should eq 2
        rule.limit.should eq 2
        rule.prefix.should eq "x"
      end

      it "loads nilable properties as nil" do
        rule = load_rule <<-YAML
          Ameba/ConfigRule:
            Limit: ~
          YAML

        rule.limit.should be_nil
      end

      it "loads enums, hashes and tuples" do
        rule = load_rule <<-YAML
          Ameba/ConfigRule:
            Options: [foo, bar]
            Severities: {warning: 2}
            Pair: [b, 3]
            Record: {a: 4}
          YAML

        rule.options.should eq ConfigRule::Option::Foo | ConfigRule::Option::Bar
        rule.severities.should eq({Severity::Warning => 2})
        rule.pair.should eq({"b", 3})
        rule.record.should eq({a: 4, b: nil})
      end

      it "loads unions" do
        load_rule("Ameba/ConfigRule: {Either: b}").either.should eq "b"
        load_rule("Ameba/ConfigRule: {Either: [b, c]}").either.should eq %w[b c]
      end

      it "loads built-in properties" do
        rule = load_rule <<-YAML
          Ameba/ConfigRule:
            Enabled: false
            Severity: error
            Excluded: [a.cr]
            SinceVersion: 1.2.3
          YAML

        rule.enabled?.should be_false
        rule.severity.should eq Severity::Error
        rule.excluded.should eq Set{"a.cr"}
        rule.since_version.should eq SemanticVersion.parse("1.2.3")
      end

      it "loads the severity defined within `properties`" do
        ConfigSeverityRule.new.severity.should eq Severity::Warning
        ConfigSeverityRule.new(YAML.parse("Ameba/ConfigSeverityRule: {Severity: error}"))
          .severity.should eq Severity::Error
      end

      it "ignores unknown keys" do
        load_rule("Ameba/ConfigRule: {Unknown: 1}").count.should eq 1
      end

      it "raises on invalid values" do
        expect_raises(YAML::ParseException, "Can't read Int32") do
          load_rule("Ameba/ConfigRule: {Count: x}")
        end
        expect_raises(YAML::ParseException, "Expected sequence, not scalar") do
          load_rule("Ameba/ConfigRule: {Options: foo}")
        end
        expect_raises(YAML::ParseException, "Expected 2 elements, not 1") do
          load_rule("Ameba/ConfigRule: {Pair: [a]}")
        end
        expect_raises(YAML::ParseException, "Missing yaml attribute: a") do
          load_rule("Ameba/ConfigRule: {Record: {b: x}}")
        end
        expect_raises(Exception, "Incorrect severity name foo") do
          load_rule("Ameba/ConfigRule: {Severity: foo}")
        end
      end
    end

    describe "#to_yaml" do
      it "writes properties by their camelcased keys" do
        YAML.parse(ConfigRule.new.to_yaml).should eq YAML.parse(<<-YAML)
          Description: Rule to test loading its properties from YAML
          Count: 1
          Limit: 2
          Prefix: x
          Strict: false
          Names: [a]
          Options: [foo]
          Severities: {error: 1}
          Pair: [a, 1]
          Record: {a: 1, b: ~}
          Either: a
          Enabled: true
          Severity: Convention
          YAML
      end

      it "writes the severity defined within `properties`" do
        YAML.parse(ConfigSeverityRule.new.to_yaml)["Severity"]
          .should eq "Warning"
      end

      it "writes properties which can be loaded back" do
        rule = load_rule <<-YAML
          Ameba/ConfigRule:
            Count: 2
            Names: [b, c]
            Options: [foo, bar]
            Severities: {warning: 2}
            Pair: [b, 3]
            Record: {a: 4, b: y}
            Either: [b, c]
            Enabled: false
            Severity: error
            Excluded: [a.cr]
            SinceVersion: 1.2.3
          YAML

        ConfigRule.from_yaml(rule.to_yaml).to_yaml
          .should eq rule.to_yaml
      end
    end

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
