require "./ameba"
require "./ameba/json_schema/*"

JSON_SCHEMA_FILEPATH =
  Path[".ameba.yml.schema.json"]

Ameba::JSONSchema::Builder.build(JSON_SCHEMA_FILEPATH)
