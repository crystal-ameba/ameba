require "../spec_helper"

module Ameba
  describe Config do
    config_sample = "spec/fixtures/config.yml"

    it "should have a list of available formatters" do
      Config::AVAILABLE_FORMATTERS.should_not be_nil
    end

    describe ".new" do
      it "raises when the config is not a Hash" do
        yml = YAML.parse "[]"
        expect_raises(Exception, "Invalid config file format") do
          Config.new(yml)
        end
      end

      it "loads default globs when config is empty" do
        yml = YAML.parse "{}"
        config = Config.new(yml)
        config.globs.should eq Config::DEFAULT_GLOBS
      end

      it "loads default globs when config has no value" do
        yml = YAML.parse <<-CONFIG
          # Empty config with comment
          CONFIG
        config = Config.new(yml)
        config.globs.should eq Config::DEFAULT_GLOBS
      end

      it "initializes globs as string" do
        yml = YAML.parse <<-CONFIG
          ---
          Globs: src/*.cr
          CONFIG
        config = Config.new(yml)
        config.globs.should eq Set{"src/*.cr"}
      end

      it "initializes globs as array" do
        yml = YAML.parse <<-CONFIG
          ---
          Globs:
           - "src/*.cr"
           - "!spec"
          CONFIG
        config = Config.new(yml)
        config.globs.should eq Set{"src/*.cr", "!spec"}
      end

      it "raises if Globs has a wrong type" do
        yml = YAML.parse <<-CONFIG
          ---
          Globs: 100
          CONFIG
        expect_raises(Exception, "Incorrect 'Globs' section in a config file") do
          Config.new(yml)
        end
      end

      it "initializes excluded as string" do
        yml = YAML.parse <<-CONFIG
          ---
          Excluded: spec
          CONFIG
        config = Config.new(yml)
        config.excluded.should eq Set{"spec"}
      end

      it "initializes excluded as array" do
        yml = YAML.parse <<-CONFIG
          ---
          Excluded:
           - spec
           - lib/*.cr
          CONFIG
        config = Config.new(yml)
        config.excluded.should eq Set{"spec", "lib/*.cr"}
      end

      it "raises if Excluded has a wrong type" do
        yml = YAML.parse <<-CONFIG
          ---
          Excluded: true
          CONFIG
        expect_raises(Exception, "Incorrect 'Excluded' section in a config file") do
          Config.new(yml)
        end
      end
    end

    describe ".load" do
      it "loads custom config" do
        config = Config.load config_sample
        config.should_not be_nil
        config.version.should_not be_nil
        config.globs.should_not be_nil
        config.formatter.should_not be_nil
      end

      it "raises when custom config file doesn't exist" do
        expect_raises(Exception, "Unable to load config file: Config file does not exist") do
          Config.load "foo.yml"
        end
      end

      it "loads default config" do
        config = Config.load
        config.should_not be_nil
        config.version.should be_nil
        config.globs.should_not be_nil
        config.formatter.should_not be_nil
      end
    end

    describe "#globs, #globs=" do
      config = Config.load config_sample

      it "holds source globs" do
        config.globs.should eq Config::DEFAULT_GLOBS
      end

      it "allows to set globs" do
        config.globs = Set{"file.cr"}
        config.globs.should eq Set{"file.cr"}
      end
    end

    describe "#excluded, #excluded=" do
      config = Config.load config_sample

      it "defaults to empty array" do
        config.excluded.should be_empty
      end

      it "allows to set excluded" do
        config.excluded = Set{"spec"}
        config.excluded.should eq Set{"spec"}
      end
    end

    describe "#sources" do
      config = Config.load config_sample

      it "returns list of sources" do
        config.sources.size.should be > 0
        config.sources.first.should be_a Source
        config.sources.any?(&.fullpath.==(__FILE__)).should be_true
      end

      it "returns a list of sources matching globs" do
        config.globs = Set{"**/config_spec.cr"}
        config.sources.size.should eq(1)
      end

      it "returns a list of sources excluding 'Excluded'" do
        config.excluded = Set{"**/config_spec.cr"}
        config.sources.any?(&.fullpath.==(__FILE__)).should be_false
      end
    end

    describe "#formatter, formatter=" do
      config = Config.load config_sample
      formatter = DummyFormatter.new

      it "contains default formatter" do
        config.formatter.should_not be_nil
      end

      it "allows to set formatter" do
        config.formatter = formatter
        config.formatter.should eq formatter
      end

      it "allows to set formatter using a name" do
        config.formatter = :progress
        config.formatter.should_not be_nil
      end

      it "raises an error if not available formatter is set" do
        expect_raises(Exception) do
          config.formatter = :no_such_formatter
        end
      end
    end

    describe "#version, version=" do
      config = Config.load config_sample
      version = SemanticVersion.parse("1.5.0")

      it "contains default version" do
        config.version.should_not be_nil
      end

      it "allows to set version" do
        config.version = version
        config.version.should eq version
      end

      it "allows to set version using a string" do
        config.version = version.to_s
        config.version.should eq version
      end

      it "raises an error if version is not valid" do
        expect_raises(Exception) do
          config.version = "foo"
        end
      end
    end

    describe "#update_rule" do
      config = Config.load config_sample

      it "updates enabled property" do
        name = DummyRule.rule_name
        config.update_rule name, enabled: false
        rule = config.rules.find!(&.name.== name)
        rule.enabled?.should be_false
      end

      it "updates excluded property" do
        name = DummyRule.rule_name
        excluded = %w[spec/source.cr]
        config.update_rule name, excluded: excluded
        rule = config.rules.find!(&.name.== name)
        rule.excluded.should eq excluded
      end
    end

    describe "#update_rules" do
      config = Config.load config_sample

      it "updates multiple rules by enabled property" do
        name = DummyRule.rule_name
        config.update_rules [name], enabled: false
        rule = config.rules.find!(&.name.== name)
        rule.enabled?.should be_false
      end

      it "updates multiple rules by excluded property" do
        name = DummyRule.rule_name
        excluded = %w[spec/source.cr]
        config.update_rules [name], excluded: excluded
        rule = config.rules.find!(&.name.== name)
        rule.excluded.should eq excluded
      end

      it "updates a group of rules by enabled property" do
        group = DummyRule.group_name
        config.update_rules [group], enabled: false
        rule = config.rules.find!(&.name.== DummyRule.rule_name)
        rule.enabled?.should be_false
      end

      it "updates a group by excluded property" do
        name = DummyRule.group_name
        excluded = %w[spec/source.cr]
        config.update_rules [name], excluded: excluded
        rule = config.rules.find!(&.name.== DummyRule.rule_name)
        rule.excluded.should eq excluded
      end
    end
  end
end
