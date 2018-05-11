require "json"

module Ameba::Formatter
  # A formatter that produces the result in a json format.
  #
  # Example:
  #
  # ```
  # {
  #   "metadata": {
  #     "ameba_version":   "x.x.x",
  #     "crystal_version": "x.x.x",
  #   },
  #   "sources": [
  #     {
  #       "errors": [
  #         {
  #           "location": {
  #             "column": 7,
  #             "line":   17,
  #           },
  #           "message":   "Useless assignment to variable `a`",
  #           "rule_name": "UselessAssign",
  #         },
  #         {
  #           "location": {
  #             "column": 7,
  #             "line":   18,
  #           },
  #           "message":   "Useless assignment to variable `a`",
  #           "rule_name": "UselessAssign",
  #         },
  #         {
  #           "location": {
  #             "column": 7,
  #             "line":   19,
  #           },
  #           "message":   "Useless assignment to variable `a`",
  #           "rule_name": "UselessAssign",
  #         },
  #       ],
  #       "path": "src/ameba/formatter/json_formatter.cr",
  #     },
  #   ],
  #   "summary": {
  #     "errors_count":         3,
  #     "target_sources_count": 1,
  #   },
  # }
  # ```
  #
  class JSONFormatter < BaseFormatter
    def initialize(@output = STDOUT)
      @result = AsJSON::Result.new
    end

    def started(sources)
      @result.summary.target_sources_count = sources.size
    end

    def source_finished(source : Source)
      json_source = AsJSON::Source.new source.path

      source.errors.each do |e|
        next if e.disabled?
        json_source.errors << AsJSON::Error.new(e.rule.name, e.location, e.message)
        @result.summary.errors_count += 1
      end

      @result.sources << json_source
    end

    def finished(sources)
      @result.to_json @output
    end
  end

  private module AsJSON
    record Result,
      sources = [] of Source,
      metadata = Metadata.new,
      summary = Summary.new do
      def to_json(json)
        {sources: sources, metadata: metadata, summary: summary}.to_json(json)
      end
    end

    record Source,
      path : String,
      errors = [] of Error do
      def to_json(json)
        {path: path, errors: errors}.to_json(json)
      end
    end

    record Error,
      rule_name : String,
      location : Crystal::Location?,
      message : String do
      def to_json(json)
        json.object do
          json.field :rule_name, rule_name
          json.field :message, message
          json.field :location,
            {line: location.try &.line_number, column: location.try &.column_number}
        end
      end
    end

    record Metadata,
      ameba_version : String = Ameba::VERSION,
      crystal_version : String = Crystal::VERSION do
      def to_json(json)
        json.object do
          json.field :ameba_version, ameba_version
          json.field :crystal_version, crystal_version
        end
      end
    end

    class Summary
      property target_sources_count = 0
      property errors_count = 0

      def to_json(json)
        json.object do
          json.field :target_sources_count, target_sources_count
          json.field :errors_count, errors_count
        end
      end
    end
  end
end
