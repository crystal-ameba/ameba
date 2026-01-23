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
      # TODO(margret): ruleConfigurationOverrides https://github.com/dotnet/roslyn/issues/67365#issuecomment-1641906334
      # ameba_rules : Array(Rule::Base) = sources.flat_map { |source| source.issues.flat_map(&.rule) }.uniq!

      sarif_rules = Rule.rules.map do |rule_class|
        rule = rule_class.new

        AsSARIF::ReportingDescriptor.new(
          id: rule.name,
          name: rule.name,
          short_description: rule.description,
          full_description: rule.class.parsed_doc || "",
          help_uri: rule.class.documentation_url,
          default_configuration: AsSARIF::ReportingConfiguration.new(
            enabled: rule.enabled?,
            level: AsSARIF::Level.from_severity(rule.severity),
            parameters: rule.class
          ),
        )
      end

      sarif_tool = AsSARIF::Tool.new(
        driver: AsSARIF::ToolComponent.new(
          name: "ameba",
          version: Ameba::VERSION,
          rules: sarif_rules,
          # TODO(margret): Better version-specific link
          information_uri: "https://crystal-ameba.github.io/",
        )
      )

      sarif_run = AsSARIF::Run.new(
        tool: sarif_tool
      )

      sources.each do |source|
        source.issues.each do |issue|
          next if issue.disabled?

          start_location = issue.location || issue.end_location || Crystal::Location.new(source.path, 1, 1)
          end_location = issue.end_location || start_location

          context_snippet =
            source.lines[(start_location.line_number - 1)...end_location.line_number].join('\n')

          context_region = AsSARIF::ContextRegion.new(
            start_line: start_location.line_number,
            start_column: start_location.column_number,
            end_line: end_location.line_number,
            end_column: end_location.column_number,
            snippet: context_snippet,
            source_language: source.ecr? ? "ECR" : "Crystal",
          )

          sarif_run.results << AsSARIF::RunResult.new(
            message: issue.message,
            rule_id: issue.rule.name,
            rule_index: sarif_rules.index!(&.name.== issue.rule.name),
            level: AsSARIF::Level.from_severity(issue.rule.severity),
            locations: [AsSARIF::Location.new(
              uri: Path[source.path].to_posix.to_s,
              context_region: context_region,
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
      include JSON::Serializable

      @[JSON::Field(key: "$schema")]
      property schema = "https://www.schemastore.org/schemas/json/sarif-2.1.0-rtm.6.json"
      property version = "2.1.0"
      property runs = [] of Run

      def initialize
      end
    end

    struct Run
      include JSON::Serializable

      property tool : Tool
      property results : Array(RunResult)

      def initialize(@tool, @results = Array(RunResult).new)
      end
    end

    struct RunResult
      property message : String
      property rule_id : String
      property rule_index : Int32
      property level : Level
      property locations : Array(Location)

      def initialize(@message, @rule_id, @rule_index, @level, @locations)
      end

      def to_json(json)
        {
          message: {
            text:     message,
            markdown: message,
          },
          ruleId:    rule_id,
          ruleIndex: rule_index,
          level:     level,
          locations: locations,
        }.to_json(json)
      end
    end

    struct Location
      property uri : String
      property start_location : Crystal::Location?
      property end_location : Crystal::Location?
      property context_region : ContextRegion?

      def initialize(@uri, @start_location, @end_location = nil, @context_region = nil)
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
            region:        region_data,
            contextRegion: context_region,
          },
        }.to_json(json)
      end
    end

    struct ContextRegion
      getter start_line : Int32
      getter start_column : Int32
      getter end_line : Int32
      getter end_column : Int32
      getter snippet : String
      getter source_language : String

      def initialize(@start_line, @start_column, @end_line, @end_column, @snippet, @source_language)
      end

      def to_json(json)
        {
          startLine:      start_line,
          startColumn:    start_column,
          endLine:        end_line,
          endColumn:      end_column,
          snippet:        {text: snippet},
          sourceLanguage: source_language,
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
        in .error?      then Error
        in .warning?    then Warning
        in .convention? then Note
        end
      end
    end

    struct Tool
      include JSON::Serializable

      property driver : ToolComponent

      def initialize(@driver)
      end
    end

    struct ToolComponent
      include JSON::Serializable

      property name : String
      property version : String
      @[JSON::Field(key: "informationUri")]
      property information_uri : String
      property rules : Array(ReportingDescriptor)

      def initialize(@name, @version, @information_uri, @rules)
      end
    end

    struct ReportingDescriptor
      getter id : String
      getter name : String
      getter short_description : String
      getter full_description : String
      getter default_configuration : ReportingConfiguration
      getter help_uri : String

      def initialize(@id, @name, @short_description, @full_description, @default_configuration, @help_uri)
      end

      def to_json(json)
        {
          id:               id,
          name:             name,
          shortDescription: {
            text:     short_description,
            markdown: short_description,
          },
          fullDescription: {
            text:     full_description,
            markdown: full_description,
          },
          defaultConfiguration: default_configuration,
          helpUri:              help_uri,
        }.to_json(json)
      end
    end

    struct ReportingConfiguration
      getter? enabled : Bool
      getter level : Level
      getter parameters : Rule::Base.class

      def initialize(@enabled, @level, @parameters)
      end

      def to_json(json)
        json.object do
          if !enabled?
            json.field("enabled", enabled?)
          end

          json.field("level", level)
          json.field("parameters") do
            parameters.to_sarif(json)
          end
        end
      end
    end
  end
end
