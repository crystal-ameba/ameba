module Ameba::JSONSchema::Builder
  extend self

  def build(indent = 2) : String
    String.build do |str|
      build(str, indent)
    end
  end

  def build(path : Path, indent = 2) : Nil
    File.open(path, "w") do |file|
      build(file, indent)
    end
  end

  def build(io : IO, indent = 2) : Nil
    JSON.build(io, indent: indent) do |builder|
      builder.object do
        builder.field("$schema", "https://json-schema.org/draft/2020-12/schema")
        builder.field("$id", "https://crystal-ameba.github.io/.ameba.yml.schema.json")
        builder.field("title", ".ameba.yml")
        builder.field("description", "Configuration rules for the Crystal language Ameba linter")
        builder.field("type", "object")
        builder.field("additionalProperties", false)

        builder.string("$defs")
        builder.object do
          builder.string("Severity")
          builder.object do
            builder.field("type", "string")

            builder.string("enum")
            builder.array do
              Severity.values.each do |value|
                builder.string(value.to_s)
              end
            end
          end

          builder.string("Globs")
          builder.object do
            builder.field("type", "array")
            builder.field("title", "Globbed files and paths")
            builder.field("description",
              "An array of wildcards (or paths) to include to the inspection")

            builder.string("items")
            builder.object do
              builder.field("type", "string")

              builder.string("examples")
              builder.array do
                builder.string("src/**/*.{cr,ecr}")
                builder.string("!lib")
              end
            end
          end

          builder.string("Excluded")
          builder.object do
            builder.field("type", "array")
            builder.field("title", "Excluded files and paths")
            builder.field("description",
              "An array of wildcards (or paths) to exclude from the source list")

            builder.string("items")
            builder.object do
              builder.field("type", "string")

              builder.string("examples")
              builder.array do
                builder.string("spec/fixtures/**")
                builder.string("spec/**/*.manual_spec.cr")
              end
            end
          end

          builder.string("BaseRule")
          builder.object do
            builder.field("type", "object")

            builder.string("properties")
            builder.object do
              builder.string("SinceVersion")
              builder.object do
                builder.field("type", "string")
              end

              builder.string("Enabled")
              builder.object do
                builder.field("type", "boolean")
                builder.field("default", true)
              end

              builder.string("Severity")
              builder.object do
                builder.field("$ref", "#/$defs/Severity")
                builder.field("default", Rule::Base.default_severity.to_s)
              end

              builder.string("Excluded")
              builder.object do
                builder.field("$ref", "#/$defs/Excluded")
              end
            end
          end
        end

        builder.string("properties")
        builder.object do
          builder.string("Version")
          builder.object do
            builder.field("type", "string")
            builder.field("description", "The version of Ameba to limit rules to")

            builder.string("examples")
            builder.array do
              builder.string("1.7.0")
              builder.string("1.6.4")
            end
          end

          builder.string("Globs")
          builder.object do
            builder.field("$ref", "#/$defs/Globs")
          end

          builder.string("Excluded")
          builder.object do
            builder.field("$ref", "#/$defs/Excluded")
          end

          Rule.rules.each do |rule|
            rule.to_json_schema(builder)
          end
        end
      end
    end
  end
end
