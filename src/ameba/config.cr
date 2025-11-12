require "semantic_version"
require "yaml"
require "ecr/processor"

require "./glob_utils"
require "./config/*"

# A configuration entry for `Ameba::Runner`.
#
# Config can be loaded from configuration YAML file and adjusted.
#
# ```
# config = Ameba::Config.load
# config.formatter = my_formatter
# ```
class Ameba::Config
  extend Loader

  include GlobUtils

  DEFAULT_EXCLUDED = Set{"lib"}
  DEFAULT_GLOBS    = Set{"**/*.{cr,ecr}"}

  AVAILABLE_FORMATTERS = {
    progress:         Formatter::DotFormatter,
    todo:             Formatter::TODOFormatter,
    flycheck:         Formatter::FlycheckFormatter,
    silent:           Formatter::BaseFormatter,
    disabled:         Formatter::DisabledFormatter,
    json:             Formatter::JSONFormatter,
    sarif:            Formatter::SARIFFormatter,
    "github-actions": Formatter::GitHubActionsFormatter,
  }

  # Returns available formatter names joined by *separator*.
  def self.formatter_names(separator = '|')
    AVAILABLE_FORMATTERS.keys.join(separator)
  end

  # Returns an array of configured rules.
  getter rules : Array(Rule::Base)

  # Returns minimum reported severity.
  property severity : Severity = :convention

  # Returns a root directory to be used by `Ameba::Runner`.
  property root : Path { Path[Dir.current] }

  # Returns an ameba version to be used by `Ameba::Runner`.
  property version : SemanticVersion?

  # Sets version from string.
  #
  # ```
  # config = Ameba::Config.load
  # config.version = "1.6.0"
  # ```
  def version=(version : String)
    @version = SemanticVersion.parse(version)
  end

  # Returns a formatter to be used while inspecting files.
  # If formatter is not set, it will return default formatter.
  #
  # ```
  # config = Ameba::Config.load
  # config.formatter = custom_formatter
  # config.formatter
  # ```
  property formatter : Formatter::BaseFormatter do
    Formatter::DotFormatter.new
  end

  # Sets formatter by name.
  #
  # ```
  # config = Ameba::Config.load
  # config.formatter = :progress
  # ```
  def formatter=(name : String | Symbol)
    unless formatter = AVAILABLE_FORMATTERS[name]?
      raise "Unknown formatter `#{name}`. Use one of #{Config.formatter_names}."
    end
    @formatter = formatter.new
  end

  # Returns a list of paths (with wildcards) to files.
  # Represents a list of sources to be inspected.
  # If globs are not set, it will return default list of files.
  #
  # ```
  # config = Ameba::Config.load
  # config.globs = Set{"**/*.cr"}
  # config.globs
  # ```
  property globs : Set(String)

  # Represents a list of paths to exclude from globs.
  # Can have wildcards.
  #
  # ```
  # config = Ameba::Config.load
  # config.excluded = Set{"spec", "src/server/*.cr"}
  # ```
  property excluded : Set(String)

  # Returns `true` if correctable issues should be autocorrected.
  property? autocorrect = false

  # Returns a filename if reading source file from STDIN.
  property stdin_filename : String?

  # Returns rules grouped by rule group.
  protected getter rule_groups : Hash(String, Array(Rule::Base))

  protected def initialize(
    *,
    @rules = [] of Rule::Base,
    @severity : Severity = :convention,
    @root = nil,
    @globs = Set(String).new,
    @excluded = Set(String).new,
    @autocorrect = false,
    @stdin_filename = nil,
    version = nil,
    formatter = nil,
  )
    @rule_groups = @rules.group_by &.group

    if version
      self.version = version
    end
    if formatter
      self.formatter = formatter
    end
  end

  # Returns a list of sources matching globs and excluded sections.
  #
  # ```
  # config = Ameba::Config.load
  # config.sources # => list of default sources
  # config.globs = Set{"**/*.cr", "**/*.ecr"}
  # config.excluded = Set{"spec"}
  # config.sources # => list of sources pointing to files found by the wildcards
  # ```
  def sources
    if file = stdin_filename
      [Source.new(STDIN.gets_to_end, file)]
    else
      files.map do |path|
        Source.new(File.read(path), path)
      end
    end
  end

  # Returns a list of files matching globs and excluded sections.
  #
  # ```
  # config = Ameba::Config.load
  # config.files # => list of default files
  # config.globs = Set{"**/*.cr", "**/*.ecr"}
  # config.excluded = Set{"spec"}
  # config.files # => list of files found by the wildcards
  # ```
  def files
    find_files_by_globs(globs, root) - find_files_by_globs(excluded, root)
  end

  # Updates rule properties.
  #
  # ```
  # config = Ameba::Config.load
  # config.update_rule "MyRuleName", enabled: false
  # ```
  def update_rule(name, enabled = true, excluded = nil)
    rule = @rules.find(&.name.==(name))
    raise ArgumentError.new("Rule `#{name}` does not exist") unless rule

    rule
      .tap(&.enabled = enabled)
      .tap(&.excluded = excluded.try &.to_set)
  end

  # Updates rules properties.
  #
  # ```
  # config = Ameba::Config.load
  # config.update_rules %w[Rule1 Rule2], enabled: true
  # ```
  #
  # also it allows to update groups of rules:
  #
  # ```
  # config.update_rules %w[Group1 Group2], enabled: true
  # ```
  def update_rules(names : Enumerable(String), enabled = true, excluded = nil)
    excluded = excluded.try &.to_set

    names.each do |name|
      if rules = @rule_groups[name]?
        rules.each do |rule|
          rule.enabled = enabled
          rule.excluded = excluded
        end
      else
        update_rule name, enabled, excluded
      end
    end
  end
end
