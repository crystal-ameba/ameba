require "./ameba"
require "./ameba/json_schema/*"

JSON_SCHEMA_FILEPATH =
  Path[__DIR__, "..", ".ameba.yml.schema.json"].expand

Ameba::JSONSchema::Builder.build(JSON_SCHEMA_FILEPATH)
