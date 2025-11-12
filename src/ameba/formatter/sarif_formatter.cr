require "uri"
require "json"

module Ameba::Formatter
  # SARIF v2.1.0 output formatter.
  #
  # See:
  # - https://sarifweb.azurewebsites.net/
  # - https://www.schemastore.org/sarif-2.1.0.json
  # - https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.pdf
  class SARIFFormatter < BaseFormatter
    def finished(sources) : Nil
      sarif_tool = AsSARIF::Tool.new(
        driver: AsSARIF::ToolComponent.new(
          name: "ameba",
          version: Ameba::VERSION,
          # TODO(margret): Better version-specific link
          information_uri: "https://crystal-ameba.github.io/"
        )
      )

      sarif_run = AsSARIF::Run.new(
        tool: sarif_tool
      )

      sources.each do |source|
        source.issues.each do |issue|
          next if issue.disabled?

          start_location = issue.location || issue.end_location
          end_location = issue.end_location

          sarif_run.results << AsSARIF::RunResult.new(
            message: issue.rule.description,
            rule_id: issue.rule.name,
            level: AsSARIF::Level.from_severity(issue.rule.severity),
            locations: [AsSARIF::Location.new(
              uri: "file://#{source.fullpath}",
              start_location: start_location,
              end_location: end_location
            )]
          )
        end
      end

      sarif_result = AsSARIF::Result.new
      sarif_result.runs.push(sarif_run)

      sarif_result.to_json(@output)
    end
  end

  private module AsSARIF
    struct Result
      property schema : String = "https://www.schemastore.org/sarif-2.1.0.json"
      property version : String = "2.1.0"
      property runs = Array(Run).new

      def initialize
      end

      def to_json(json)
        {
          "$schema": schema,
          version:   version,
          runs:      runs,
        }.to_json(json)
      end
    end

    struct Run
      property tool : Tool
      property results : Array(RunResult)

      def initialize(@tool, @results = Array(RunResult).new)
      end

      def to_json(json)
        {
          tool:    tool,
          results: results,
        }.to_json(json)
      end
    end

    struct RunResult
      # TODO(margret): Replace with `id` and `arguments` properties, to reference the `rules` listed in the tool component
      property message : String
      property rule_id : String
      property level : Level
      property locations : Array(Location)

      def initialize(@message, @rule_id, @level, @locations)
      end

      def to_json(json)
        {
          message: {
            text: message,
          },
          ruleId:    rule_id,
          level:     level,
          locations: locations,
        }.to_json(json)
      end
    end

    # "locations": [
    #   {
    #     "physicalLocation": {
    #       "uri": "file:///C:/Code/a.js",
    #       "region": {
    #         "startLine": "6",
    #         "startColumn": "10"
    #       }
    #     }
    #   }
    # ],
    struct Location
      # TODO(margret): use relative references
      property uri : String
      property start_location : Crystal::Location?
      property end_location : Crystal::Location?

      # TODO(margret): Add `contextRegion` pointing to a few lines of surrounding code

      # TODO(margret): Add `snippet` for the given location

      def initialize(@uri, @start_location, @end_location = nil)
      end

      def to_json(json)
        region_data = Hash(String, Int32).new

        if start_loc = start_location
          region_data["startLine"] = start_loc.line_number
          region_data["startColumn"] = start_loc.column_number
        else
          region_data["startLine"] = 1
          region_data["startColumn"] = 1
        end

        if end_loc = end_location
          region_data["endLine"] = end_loc.line_number
          region_data["endColumn"] = end_loc.column_number
        end

        {
          physicalLocation: {
            artifactLocation: {
              uri: uri,
            },
            region: region_data,
          },
        }.to_json(json)
      end
    end

    enum Level
      None
      Note
      Warning
      Error

      def self.from_severity(severity)
        case severity
        in .error?
          Error
        in .warning?
          Warning
        in .convention?
          Note
        end
      end
    end

    struct Tool
      property driver : ToolComponent

      def initialize(@driver)
      end

      def to_json(json)
        {
          driver: driver,
        }.to_json(json)
      end
    end

    struct ToolComponent
      property name : String
      property version : String?
      property information_uri : String?

      # TODO(margret): Add `versionControlProvenance` to record what version of the code was analyzed

      # TODO(margret): Add `rules` which lists all available rules

      def initialize(@name, @version = nil, @information_uri = nil)
      end

      def to_json(json)
        data = {
          "name" => name,
        }

        if v = version
          data["version"] = v
        end

        if uri = information_uri
          data["informationUri"] = uri
        end

        data.to_json(json)
      end
    end
  end
end
