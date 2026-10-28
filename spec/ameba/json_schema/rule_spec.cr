require "../../spec_helper"
require "../../../src/ameba/json_schema/*"

# Called with a rule typed as `Rule::Base.class` (the same way as the
# JSON schema builder does), so that `to_json_schema` is compiled for
# all of the rules
private def json_schema(rule : Ameba::Rule::Base.class)
  json = String.build do |io|
    JSON.build(io) do |builder|
      builder.object { rule.to_json_schema(builder) }
    end
  end

  # Ensures there are no duplicated keys, which would be dropped once parsed
  parsed = JSON.parse(json)
  parsed.to_json
    .should eq json

  parsed[rule.rule_name]
end

# Yields the JSON schema of the *rule* properties
private def with_properties_schema(rule : Ameba::Rule::Base.class, &)
  yield json_schema(rule)["properties"]
end

module Ameba
  class SchemaRule < Rule::Base
    private enum Kind
      Foo
      Bar
    end

    # Private flags enums can't be loaded from YAML
    @[Flags]
    enum Option
      Foo
      Bar
    end

    properties do
      description "Rule to test JSON schema of its properties"
      count 1
      ratio 1.5
      limit 2, as: Int32?
      precision 1, as: Float64
      prefix "x"
      names ["a".upcase]
      groups [["a"]]
      kinds [:foo] of Kind
      options :foo, as: Option
      path Path["a"]
      map({"a" => 1})
      severities({Severity::Error => 1})
      nested({"a" => [{Severity::Error => 1}]})
      pair({"a", 1})
      pairs [] of SchemaPair
      record({a: 1, b: nil}, as: NamedTuple(a: Int32, b: String?))
      either "a", as: String | Array(String)
      sequence [] of String, as: Array(String) | {String, Int32}
      either_map({"a" => 1}, as: Hash(String, Int32) | NamedTuple(a: Int32))
      mixed_map({"b" => "s"}, as: Hash(String, String) | NamedTuple(a: Int32))
      mixed_sequences({"b" => ["s"]}, as: Hash(String, Array(String)) | NamedTuple(a: Tuple(String, Int32)))
      levels [Severity::Warning]
    end
  end

  # Defined after the rule using it
  alias SchemaPair = {String, Int32}

  # Subclasses of concrete rules can't be loaded from YAML
  abstract class SchemaParentRule < Rule::Base
    properties do
      description "Rule to test JSON schema of inherited properties"
      names ["a".upcase]
    end
  end

  class SchemaSubRule < SchemaParentRule
  end

  class SchemaUndescribedRule < Rule::Base
    properties do
      description nil, as: String?
    end
  end

  class SchemaSeverityRule < Rule::Base
    properties do
      description "Rule to test JSON schema of its severity"
      severity :error
    end
  end

  class SchemaEnabledRule < Rule::Base
    properties do
      description "Rule to test JSON schema of its enabled property"
      enabled true
    end
  end

  describe Config::RuleConfig do
    describe ".to_json_schema" do
      it "describes the rule" do
        schema = json_schema(SchemaRule)
        schema["$ref"].should eq "#/$defs/BaseRule"
        schema["title"].should eq "Ameba/SchemaRule"
        schema["description"].should eq "Rule to test JSON schema of its properties"
      end

      it "skips the description if it's nil" do
        json_schema(SchemaUndescribedRule).as_h.has_key?("description").should be_false
      end

      it "describes the rule subclasses" do
        schema = json_schema(SchemaSubRule)
        schema["title"].should eq "Ameba/SchemaSubRule"
        schema["properties"]["Names"].should eq JSON.parse(<<-JSON)
          {"type": "array", "items": {"type": "string"}, "default": ["A"]}
          JSON
      end

      it "describes integers and floats" do
        with_properties_schema(SchemaRule) do |properties|
          properties["Count"].should eq JSON.parse(%({"type": "integer", "default": 1}))
          properties["Ratio"].should eq JSON.parse(%({"type": "number", "default": 1.5}))
          properties["Limit"].should eq JSON.parse(%({"type": ["integer", "null"], "default": 2}))
        end
      end

      it "writes defaults the way they are loaded" do
        with_properties_schema(SchemaRule) do |properties|
          properties["Precision"]["default"].as_f.should eq 1.0
          properties["Options"].should eq JSON.parse(<<-JSON)
            {"type": "array", "items": {"type": "string"}, "default": ["foo"]}
            JSON
        end
      end

      it "describes strings, paths and enums" do
        with_properties_schema(SchemaRule) do |properties|
          properties["Prefix"].should eq JSON.parse(%({"type": "string", "default": "x"}))
          properties["Path"].should eq JSON.parse(%({"type": "string", "default": "a"}))
        end
      end

      it "describes array items" do
        with_properties_schema(SchemaRule) do |properties|
          properties["Names"].should eq JSON.parse(<<-JSON)
            {"type": "array", "items": {"type": "string"}, "default": ["A"]}
            JSON

          properties["Groups"].should eq JSON.parse(<<-JSON)
            {"type": "array", "items": {"type": "array", "items": {"type": "string"}}, "default": [["a"]]}
            JSON

          properties["Kinds"].should eq JSON.parse(<<-JSON)
            {"type": "array", "items": {"type": "string"}, "default": ["foo"]}
            JSON
        end
      end

      it "describes hashes" do
        with_properties_schema(SchemaRule) do |properties|
          properties["Map"].should eq JSON.parse(<<-JSON)
            {
              "type": "object",
              "properties": {"a": {"type": "integer", "default": 1}},
              "additionalProperties": {"type": "integer"},
              "default": {"a": 1}
            }
            JSON
        end
      end

      it "writes hash keys as strings" do
        with_properties_schema(SchemaRule) do |properties|
          properties["Severities"].should eq JSON.parse(<<-JSON)
            {
              "type": "object",
              "properties": {"Error": {"type": "integer", "default": 1}},
              "additionalProperties": {"type": "integer"},
              "default": {"Error": 1}
            }
            JSON

          properties["Nested"]["default"].should eq JSON.parse(%({"a": [{"Error": 1}]}))
        end
      end

      it "describes tuples by position" do
        tuple = %("prefixItems": [{"type": "string"}, {"type": "integer"}], "minItems": 2, "maxItems": 2)

        with_properties_schema(SchemaRule) do |properties|
          properties["Pair"].should eq JSON.parse(<<-JSON)
            {"type": "array", #{tuple}, "default": ["a", 1]}
            JSON

          properties["Pairs"].should eq JSON.parse(<<-JSON)
            {"type": "array", "items": {"type": "array", #{tuple}}, "default": []}
            JSON
        end
      end

      it "describes named tuples with their required keys" do
        with_properties_schema(SchemaRule) do |properties|
          properties["Record"].should eq JSON.parse(<<-JSON)
            {
              "type": "object",
              "properties": {
                "a": {"type": "integer", "default": 1},
                "b": {"type": ["string", "null"], "default": null}
              },
              "required": ["a"],
              "default": {"a": 1, "b": null}
            }
            JSON
        end
      end

      it "describes unions" do
        with_properties_schema(SchemaRule) do |properties|
          properties["Either"].should eq JSON.parse(<<-JSON)
            {"type": ["array", "string"], "items": {"type": "string"}, "default": "a"}
            JSON

          properties["Sequence"].should eq JSON.parse(<<-JSON)
            {"type": "array", "items": {"type": ["string", "integer"]}, "default": []}
            JSON

          properties["EitherMap"].should eq JSON.parse(<<-JSON)
            {
              "type": "object",
              "properties": {"a": {"type": "integer", "default": 1}},
              "additionalProperties": {"type": "integer"},
              "default": {"a": 1}
            }
            JSON
        end
      end

      it "admits hash values at the named tuple keys within the same union" do
        with_properties_schema(SchemaRule) do |properties|
          properties["MixedMap"].should eq JSON.parse(<<-JSON)
            {
              "type": "object",
              "properties": {
                "a": {"type": ["integer", "string"]},
                "b": {"type": "string", "default": "s"}
              },
              "additionalProperties": {"type": "string"},
              "default": {"b": "s"}
            }
            JSON

          # Tuples don't impose their size on arrays accepted through the hash
          properties["MixedSequences"].should eq JSON.parse(<<-JSON)
            {
              "type": "object",
              "properties": {
                "a": {"type": "array", "items": {"type": ["string", "integer"]}},
                "b": {"type": "array", "items": {"type": "string"}, "default": ["s"]}
              },
              "additionalProperties": {"type": "array", "items": {"type": "string"}},
              "default": {"b": ["s"]}
            }
            JSON
        end

        SchemaRule.from_yaml("MixedMap: {a: valid}").mixed_map
          .should eq({"a" => "valid"})
      end

      it "describes built-in properties only if their defaults differ" do
        with_properties_schema(DummyRule) do |properties|
          keys = properties.as_h.keys

          keys.should_not contain "Enabled"
          keys.should_not contain "Severity"
        end

        with_properties_schema(DeprecatedRule) do |properties|
          properties["Enabled"].should eq JSON.parse(%({"type": "boolean", "default": false}))
        end

        with_properties_schema(Rule::Performance::AnyAfterFilter) do |properties|
          properties["Severity"].should eq JSON.parse(%({"$ref": "#/$defs/Severity", "default": "Warning"}))
        end

        with_properties_schema(SchemaSeverityRule) do |properties|
          properties["Severity"].should eq JSON.parse(%({"$ref": "#/$defs/Severity", "default": "Error"}))
        end

        # Defined within the rule, the same way as within `BaseRule`
        with_properties_schema(SchemaEnabledRule) do |properties|
          properties.as_h.keys.should_not contain "Enabled"
        end
      end

      it "describes severities by their definition" do
        with_properties_schema(SchemaRule) do |properties|
          properties["Levels"].should eq JSON.parse(<<-JSON)
            {"type": "array", "items": {"$ref": "#/$defs/Severity"}, "default": ["Warning"]}
            JSON
        end
      end
    end
  end
end
