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
      sarif_rules = Rule.rules.map do |rule_class|
        rule = rule_class.new

        AsSARIF::ReportingDescriptor.new(
          id: rule.name,
          short_description: rule.description,
          full_description: rule.class.parsed_doc || "",
          help_uri: rule.class.documentation_url,
          default_configuration: AsSARIF::ReportingConfiguration.new(
            enabled: rule.enabled?,
            level: AsSARIF::Level.from_severity(rule.severity),
            rule_class: rule.class
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

      # Execution fails if any source has syntax errors
      execution_successful = sources.none? { |src| src.issues.any?(&.rule.is_a?(Rule::Lint::Syntax)) }
      overrides = @rules.try { |rules| build_configuration_overrides(rules, sarif_rules) } ||
                  Array(AsSARIF::ConfigurationOverride).new

      sarif_run.invocations = [AsSARIF::Invocation.new(execution_successful, overrides)]

      sources.each do |source|
        source.issues.each do |issue|
          next if issue.disabled?

          start_location = issue.location || issue.end_location || Crystal::Location.new(source.path, 1, 1)
          end_location = issue.end_location || start_location

          # Calculate context bounds (2 lines before/after, clamped to file)
          context_start_line = {1, start_location.line_number - 2}.max
          context_end_line = {source.lines.size, end_location.line_number + 2}.min

          # Only create contextRegion if it's a proper superset of region
          if context_start_line < start_location.line_number ||
             context_end_line > end_location.line_number
            context_snippet = source.lines[(context_start_line - 1)...context_end_line].join('\n')
            context_region = AsSARIF::ContextRegion.new(
              start_line: context_start_line,
              end_line: context_end_line,
              snippet: context_snippet,
              source_language: source.ecr? ? "ECR" : "Crystal",
            )
          end

          sarif_run.results << AsSARIF::RunResult.new(
            message: issue.message,
            rule_id: issue.rule.name,
            rule_index: sarif_rules.index!(&.id.== issue.rule.name),
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

    private def build_configuration_overrides(
      configured_rules : Array(Rule::Base),
      sarif_rules : Array(AsSARIF::ReportingDescriptor),
    ) : Array(AsSARIF::ConfigurationOverride)
      overrides = [] of AsSARIF::ConfigurationOverride

      configured_rules.each do |configured_rule|
        default_rule = configured_rule.class.new

        # Check if enabled or severity differs from default
        enabled_differs = configured_rule.enabled? != default_rule.enabled?
        severity_differs = configured_rule.severity != default_rule.severity

        if enabled_differs || severity_differs
          # Find the rule index in sarif_rules array
          rule_index = sarif_rules.index! { |rule| rule.id == configured_rule.name }

          overrides << AsSARIF::ConfigurationOverride.new(
            descriptor: AsSARIF::ReportingDescriptorReference.new(
              id: configured_rule.name,
              index: rule_index
            ),
            configuration: AsSARIF::ReportingConfiguration.new(
              enabled: configured_rule.enabled?,
              level: AsSARIF::Level.from_severity(configured_rule.severity),
              rule_class: configured_rule.class
            )
          )
        end
      end

      overrides
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
      property invocations : Array(Invocation)?

      def initialize(@tool, @results = Array(RunResult).new, @invocations = nil)
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

        json.object do
          json.field "physicalLocation" do
            json.object do
              json.field "artifactLocation" do
                json.object do
                  json.field "uri", uri
                end
              end
              json.field "region", region_data
              if ctx = context_region
                json.field "contextRegion", ctx
              end
            end
          end
        end
      end
    end

    struct ContextRegion
      getter start_line : Int32
      getter end_line : Int32
      getter snippet : String
      getter source_language : String

      def initialize(@start_line, @end_line, @snippet, @source_language)
      end

      def to_json(json)
        {
          startLine:      start_line,
          endLine:        end_line,
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
      getter short_description : String
      getter full_description : String
      getter default_configuration : ReportingConfiguration
      getter help_uri : String

      def initialize(@id, @short_description, @full_description, @default_configuration, @help_uri)
      end

      def to_json(json)
        {
          id:               id,
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
      getter rule_class : Rule::Base.class

      def initialize(@enabled, @level, @rule_class)
      end

      def to_json(json)
        json.object do
          if !enabled?
            json.field("enabled", false)
          end

          json.field("level", level)
          json.field("parameters") do
            rule_class.to_sarif(json)
          end
        end
      end
    end

    struct ReportingDescriptorReference
      property id : String
      property index : Int32

      def initialize(@id, @index)
      end

      def to_json(json)
        {
          id:    id,
          index: index,
        }.to_json(json)
      end
    end

    struct ConfigurationOverride
      property descriptor : ReportingDescriptorReference
      property configuration : ReportingConfiguration

      def initialize(@descriptor, @configuration)
      end

      def to_json(json)
        {
          descriptor:    descriptor,
          configuration: configuration,
        }.to_json(json)
      end
    end

    struct Invocation
      include JSON::Serializable

      @[JSON::Field(key: "executionSuccessful")]
      property? execution_successful : Bool = true

      @[JSON::Field(key: "ruleConfigurationOverrides")]
      property rule_configuration_overrides : Array(ConfigurationOverride)

      def initialize(@execution_successful = true, @rule_configuration_overrides = [] of ConfigurationOverride)
      end
    end
  end
end
