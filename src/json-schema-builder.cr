require "./ameba"
require "./ameba/json_schema/*"

module Ameba::JSONSchema
  PATH = Path[__DIR__, "..", ".ameba.yml.schema.json"].expand

  Builder.build(PATH)
end
