require "json"

module Ameba::Formatter
  # A formatter that produces the result in a json format.
  #
  # Example:
  #
  # ```json
  # {
  #   "metadata": {
  #     "ameba_version": "x.x.x",
  #     "crystal_version": "x.x.x",
  #   },
  #   "sources": [
  #     {
  #       "issues": [
  #         {
  #           "location": {
  #             "column": 7,
  #             "line": 17,
  #           },
  #           "end_location": {
  #             "column": 20,
  #             "line": 17,
  #           },
  #           "message": "Useless assignment to variable `a`",
  #           "rule_name": "UselessAssign",
  #           "severity": "Convention",
  #         },
  #         {
  #           "location": {
  #             "column": 7,
  #             "line": 18,
  #           },
  #           "end_location": {
  #             "column": 8,
  #             "line": 18,
  #           },
  #           "message": "Useless assignment to variable `a`",
  #           "rule_name": "UselessAssign",
  #         },
  #         {
  #           "location": {
  #             "column": 7,
  #             "line": 19,
  #           },
  #           "end_location": {
  #             "column": 9,
  #             "line": 19,
  #           },
  #           "message": "Useless assignment to variable `a`",
  #           "rule_name": "UselessAssign",
  #           "severity": "Convention",
  #         },
  #       ],
  #       "path": "src/ameba/formatter/json_formatter.cr",
  #     },
  #   ],
  #   "summary": {
  #     "issues_count": 3,
  #     "target_sources_count": 1,
  #   }
  # }
  # ```
  class JSONFormatter < BaseFormatter
    @result = AsJSON::Result.new
    @mutex = Mutex.new

    def started(sources) : Nil
      @result.summary.target_sources_count = sources.size
    end

    def source_finished(source : Source) : Nil
      json_source = AsJSON::Source.new source.path

      source.issues.each do |issue|
        next if issue.disabled?
        next if issue.correctable? && config[:autocorrect]?

        json_source.issues << AsJSON::Issue.new(
          issue.rule.name,
          issue.rule.severity.to_s,
          issue.location,
          issue.end_location,
          issue.message
        )
      end

      @mutex.synchronize do
        @result.summary.issues_count += json_source.issues.size
        @result.sources << json_source
      end
    end

    def finished(sources) : Nil
      @result.to_json @output
    end
  end

  private module AsJSON
    record Result,
      sources = [] of Source,
      metadata = Metadata.new,
      summary = Summary.new do
      def to_json(json)
        {
          sources:  sources,
          metadata: metadata,
          summary:  summary,
        }.to_json(json)
      end
    end

    record Source,
      path : String,
      issues = [] of Issue do
      def to_json(json)
        {
          path:   path,
          issues: issues,
        }.to_json(json)
      end
    end

    record Issue,
      rule_name : String,
      severity : String,
      location : Crystal::Location?,
      end_location : Crystal::Location?,
      message : String do
      def to_json(json)
        {
          rule_name: rule_name,
          severity:  severity,
          message:   message,
          location:  {
            line:   location.try &.line_number,
            column: location.try &.column_number,
          },
          end_location: {
            line:   end_location.try &.line_number,
            column: end_location.try &.column_number,
          },
        }.to_json(json)
      end
    end

    record Metadata,
      ameba_version : String = Ameba::VERSION,
      crystal_version : String = Crystal::VERSION do
      def to_json(json)
        {
          ameba_version:   ameba_version,
          crystal_version: crystal_version,
        }.to_json(json)
      end
    end

    class Summary
      property target_sources_count = 0
      property issues_count = 0

      def to_json(json)
        {
          target_sources_count: target_sources_count,
          issues_count:         issues_count,
        }.to_json(json)
      end
    end
  end
end
