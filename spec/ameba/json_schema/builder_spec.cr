require "../../spec_helper"
require "../../../src/ameba/json_schema/*"

# Returns all of the `$ref` values found within the given *json*
private def json_schema_refs(json : JSON::Any) : Array(String)
  refs = [] of String

  case raw = json.raw
  when Hash
    raw.each do |key, value|
      if key == "$ref" && (ref = value.as_s?)
        refs << ref
      else
        refs.concat(json_schema_refs(value))
      end
    end
  when Array
    raw.each { |value| refs.concat(json_schema_refs(value)) }
  end

  refs
end

module Ameba
  describe JSONSchema::Builder do
    json = JSONSchema::Builder.build
    schema = JSON.parse(json)

    describe ".build" do
      it "writes the schema without duplicated keys" do
        # Duplicated keys would be dropped once parsed
        schema.to_pretty_json(indent: "  ")
          .should eq json
      end

      it "writes the schema metadata" do
        schema["$schema"].should eq "https://json-schema.org/draft/2020-12/schema"
        schema["$id"].should eq "https://crystal-ameba.org/.ameba.yml.schema.json"
        schema["title"].should eq ".ameba.yml"
        schema["type"].should eq "object"
        schema["additionalProperties"].should be_false
      end

      it "writes the definitions" do
        schema["$defs"].as_h.keys.should eq JSONSchema::Builder::DEFINITIONS
      end

      it "describes severities by their names" do
        schema["$defs"]["Severity"].should eq JSON.parse({
          type: "string",
          enum: Severity.values.map(&.to_s),
        }.to_json)
      end

      it "describes globs and excluded paths as arrays of strings" do
        {"Globs", "Excluded"}.each do |key|
          definition = schema["$defs"][key]
          definition["type"].should eq "array"
          definition["items"]["type"].should eq "string"
        end
      end

      it "describes the properties common to all of the rules within `BaseRule`" do
        schema["$defs"]["BaseRule"].should eq JSON.parse(<<-JSON)
          {
            "type": "object",
            "properties": {
              "SinceVersion": {"type": ["string", "null"]},
              "Enabled": {"type": "boolean", "default": true},
              "Severity": {"$ref": "#/$defs/Severity", "default": "Convention"},
              "Excluded": {"$ref": "#/$defs/Excluded"}
            }
          }
          JSON
      end

      it "describes the top-level config keys" do
        properties = schema["properties"]

        properties["Version"]["type"].should eq "string"
        properties["Globs"].should eq JSON.parse(%({"$ref": "#/$defs/Globs"}))
        properties["Excluded"].should eq JSON.parse(%({"$ref": "#/$defs/Excluded"}))

        properties["Formatter"]["properties"]["Name"]["enum"].as_a.map(&.as_s)
          .should eq Config::AVAILABLE_FORMATTERS.keys.map(&.to_s).to_a
      end

      it "describes all of the rules" do
        properties = schema["properties"]

        Rule.rules.each do |rule|
          properties[rule.rule_name]["$ref"].should eq "#/$defs/BaseRule"
        end

        rule_keys = properties.as_h.keys - %w[Version Formatter Globs Excluded]
        rule_keys.should eq Rule.rules.map(&.rule_name)
      end

      it "refers only to the existing definitions" do
        definitions = schema["$defs"].as_h.keys

        json_schema_refs(schema).uniq.each do |ref|
          ref.should start_with "#/$defs/"
          definitions.should contain ref.lchop("#/$defs/")
        end
      end

      it "writes the schema with the given indentation" do
        JSONSchema::Builder.build(indent: 4)
          .should eq schema.to_pretty_json(indent: "    ")
      end

      it "writes the schema into the given IO" do
        io = IO::Memory.new
        JSONSchema::Builder.build(io)
        io.to_s.should eq json
      end

      it "writes the schema into the given file" do
        file = File.tempfile("builder", ".json")
        JSONSchema::Builder.build(Path[file.path])

        File.read(file.path).should eq json
      ensure
        file.try(&.delete)
      end
    end
  end
end
