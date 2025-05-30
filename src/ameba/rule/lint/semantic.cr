module Ameba::Rule::Lint
  # A rule that reports invalid Crystal semantics.
  class Semantic < Base
    properties do
      since_version "1.7.0"
      description "Reports invalid Crystal semantics"
      severity :error
    end

    def test(source, context : SemanticContext?)
      return
    end

    def test(source, sources : Array(Source)) : SemanticContext?
      SemanticContext.for_entrypoint([source])
    rescue ex : Crystal::TypeException
      # TODO: other exception types

      # Attach to the entrypoint if it's not one of our sources
      source = sources.find(source) { |i| i.path == ex.@filename }
      filename = ex.@filename || source.path

      location = Crystal::Location.new(
        filename: filename,
        line_number: ex.line_number || 0,
        column_number: ex.column_number
      )

      issue_for location, location, ex.message.to_s

      nil
    end
  end
end
