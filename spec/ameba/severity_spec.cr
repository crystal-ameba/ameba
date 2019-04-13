require "../spec_helper"

module Ameba
  describe Severity do
    describe ".default" do
      it "returns default severity" do
        Severity.default.should eq Severity::Refactoring
      end
    end

    describe ".from_name" do
      it "creates error severity by name" do
        Severity.from_name("Error").should eq Severity::Error
      end

      it "creates warning severity by name" do
        Severity.from_name("Warning").should eq Severity::Warning
      end

      it "creates refactoring severity by name" do
        Severity.from_name("Refactoring").should eq Severity::Refactoring
      end

      it "raises when name is incorrect" do
        expect_raises(Exception, "Incorrect severity name BadName. Try one of [Error, Warning, Refactoring]") do
          Severity.from_name("BadName")
        end
      end
    end
  end

  struct SeverityConvertable
    YAML.mapping(
      severity: { type: Severity, converter: SeverityYamlConverter }
    )
  end

  describe SeverityYamlConverter do
    describe ".from_yaml" do
      it "converts from yaml to Severity::Error" do
        yaml = { severity: "error" }.to_yaml
        converted = SeverityConvertable.from_yaml(yaml)
        converted.severity.should eq Severity::Error
      end

      it "converts from yaml to Severity::Warning" do
        yaml = { severity: "warning" }.to_yaml
        converted = SeverityConvertable.from_yaml(yaml)
        converted.severity.should eq Severity::Warning
      end

      it "converts from yaml to Severity::Refactoring" do
        yaml = { severity: "refactoring" }.to_yaml
        converted = SeverityConvertable.from_yaml(yaml)
        converted.severity.should eq Severity::Refactoring
      end
    end

    describe ".to_yaml" do
      it "converts Severity::Error to yaml" do
        yaml = { severity: "error" }.to_yaml
        converted = SeverityConvertable.from_yaml(yaml).to_yaml
        converted.should eq "---\nseverity: Error\n"
      end

      it "converts Severity::Warning to yaml" do
        yaml = { severity: "warning" }.to_yaml
        converted = SeverityConvertable.from_yaml(yaml).to_yaml
        converted.should eq "---\nseverity: Warning\n"
      end

      it "converts Severity::Refactoring to yaml" do
        yaml = { severity: "refactoring" }.to_yaml
        converted = SeverityConvertable.from_yaml(yaml).to_yaml
        converted.should eq "---\nseverity: Refactoring\n"
      end
    end
  end
end
