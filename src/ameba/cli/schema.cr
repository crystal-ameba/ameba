require "./cmd"

schema = JSON.build(2) do |bld|
  bld.object do
    bld.field("$schema", "http://json-schema.org/draft-07/schema#")
    bld.field("title", ".ameba.yml")
    bld.field("description", "Configuration rules for the Crystal lang ameba linter")
    bld.field("type", "object")
    bld.field("additionalProperties", false)

    bld.string("properties")
    bld.object do
      bld.string("Excluded")
      bld.object do
        bld.field("type", "array")
        bld.field("title", "excluded files and paths")
        bld.field("description", "an array of wildcards (or paths) to exclude from the source list")

        bld.string("items")
        bld.object do
          bld.field("type", "string")
        end
      end

      bld.string("Version")
      bld.object do
        bld.field("type", "string")
        bld.field("description", "the version of ameba to limit rules to")
      end

      bld.string("Globs")
      bld.object do
        bld.field("type", "array")
        bld.field("title", "globbed files and paths")
        bld.field("description", "an array of wildcards (or paths) to include to the inspection")

        bld.string("items")
        bld.object do
          bld.field("type", "string")
        end
      end

      Ameba::Rule.rules.each do |rule|
        rule.to_json_schema(bld)
      end
    end
  end
end

File.write(".ameba.yml.schema.json", schema)
