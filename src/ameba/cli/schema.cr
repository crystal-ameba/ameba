require "./cmd"

schema = JSON.build(2) do |builder|
  builder.object do
    builder.field("$schema", "http://json-schema.org/draft-07/schema#")
    builder.field("title", ".ameba.yml")
    builder.field("description", "Configuration rules for the Crystal language Ameba linter")
    builder.field("type", "object")
    builder.field("additionalProperties", false)

    builder.string("properties")
    builder.object do
      builder.string("Excluded")
      builder.object do
        builder.field("type", "array")
        builder.field("title", "Excluded files and paths")
        builder.field("description", "An array of wildcards (or paths) to exclude from the source list")

        builder.string("items")
        builder.object do
          builder.field("type", "string")
        end
      end

      builder.string("Version")
      builder.object do
        builder.field("type", "string")
        builder.field("description", "The version of Ameba to limit rules to")
      end

      builder.string("Globs")
      builder.object do
        builder.field("type", "array")
        builder.field("title", "Globbed files and paths")
        builder.field("description", "An array of wildcards (or paths) to include to the inspection")

        builder.string("items")
        builder.object do
          builder.field("type", "string")
        end
      end

      Ameba::Rule.rules.each do |rule|
        rule.to_json_schema(builder)
      end
    end
  end
end

File.write(".ameba.yml.schema.json", schema)
