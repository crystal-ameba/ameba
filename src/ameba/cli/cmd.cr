require "option_parser"
require "../../ameba"

# :nodoc:
module Ameba::CLI
  extend self

  private class Opts
    property config : Path?
    property version : String?
    property formatter : Symbol | String?
    property root = Path[Dir.current]
    property globs : Set(String)?
    property excluded : Set(String)?
    property only : Set(String)?
    property except : Set(String)?
    property describe_rule : String?
    property location_to_explain : Crystal::Location?
    property severity : Severity?
    property stdin_filename : String?
    property? skip_reading_config = false
    property? rules = false
    property? rule_versions = false
    property? all = false
    property? colors = true
    property? without_affected_code = false
    property? autocorrect = false
  end

  private class ExitException < Exception
    getter code : Int32

    def initialize(@code = 0)
      super("Exit with code #{code}")
    end
  end

  def run(args = ARGV, output : IO = STDOUT) : Bool
    safe_colorize_toggle do
      opts = parse_args(args, output: output)

      Colorize.enabled = opts.colors?

      if (location_to_explain = opts.location_to_explain) && opts.autocorrect?
        raise "Invalid usage: Cannot explain an issue and autocorrect at the same time."
      end

      if opts.stdin_filename && opts.autocorrect?
        raise "Invalid usage: Cannot autocorrect from stdin."
      end

      config = config_from_opts(opts)

      if opts.rules?
        print_rules(config.rules, output)
        return true
      end

      if opts.rule_versions?
        print_rule_versions(config.rules, output)
        return true
      end

      if describe_rule_name = opts.describe_rule
        unless rule = config.rules.find(&.name.== describe_rule_name)
          raise "Unknown rule: #{describe_rule_name}"
        end
        describe_rule(rule, output)
        return true
      end

      runner = Ameba.run(config)

      if location_to_explain
        runner.explain(location_to_explain, output)
        return true
      end

      runner.success?
    end
  rescue ex : ExitException
    ex.code.zero?
  end

  private def safe_colorize_toggle(&)
    prev_colorize_enabled = Colorize.enabled?
    begin
      yield
    ensure
      Colorize.enabled = prev_colorize_enabled
    end
  end

  # ameba:disable Metrics/CyclomaticComplexity
  def parse_args(args, opts = Opts.new, output : IO = STDOUT)
    OptionParser.parse(args) do |parser|
      parser.banner = "Usage: ameba [options] [file1 file2 ...]"

      parser.unknown_args do |arr|
        case
        when arr.size == 1 && arr.first == "-"
          opts.stdin_filename = arr.first
        when arr.size == 1 && arr.first.matches?(/.+:\d+:\d+/)
          configure_explain_opts(arr.first, opts)
        else
          configure_globs(arr, opts) if arr.present?
        end
      end

      parser.on("-v", "--version", "Print version") do
        print_version(output)
        raise ExitException.new
      end

      parser.on("-h", "--help", "Show this help") do
        print_help(parser, output)
        raise ExitException.new
      end

      parser.on("-r", "--rules", "Show all available rules") do
        opts.rules = true
      end

      parser.on("-R", "--rule-versions", "Show all available rule versions") do
        opts.rule_versions = true
      end

      parser.on("-s", "--silent", "Disable output") do
        opts.formatter = :silent
      end

      parser.on("-c", "--config PATH", "Specify a configuration file") do |path|
        opts.config = Path[path] if path.presence
      end

      parser.on("-u", "--up-to-version VERSION", "Choose a version") do |version|
        opts.version = version if version.presence
      end

      parser.on("-f", "--format FORMATTER",
        "Choose an output formatter: #{Config.formatter_names}") do |formatter|
        opts.formatter = formatter if formatter.presence
      end

      parser.on("--only RULE1,RULE2,...",
        "Run only given rules (or groups)") do |rules|
        opts.only = rules.split(',').to_set if rules.presence
      end

      parser.on("--except RULE1,RULE2,...",
        "Disable the given rules (or groups)") do |rules|
        opts.except = rules.split(',').to_set if rules.presence
      end

      parser.on("--all", "Enable all available rules") do
        opts.all = true
      end

      parser.on("--fix", "Autocorrect issues") do
        opts.autocorrect = true
      end

      parser.on("--gen-config",
        "Generate a configuration file acting as a TODO list") do
        opts.formatter = :todo
        opts.skip_reading_config = true
      end

      parser.on("--min-severity SEVERITY",
        "Minimum severity of issues to report (default: #{Rule::Base.default_severity})") do |level|
        opts.severity = Severity.parse(level) if level.presence
      end

      parser.on("-e", "--explain PATH:line:column",
        "Explain an issue at a specified location") do |loc|
        configure_explain_opts(loc, opts)
      end

      parser.on("-d", "--describe Category/Rule",
        "Describe a rule with specified name") do |rule_name|
        configure_describe_opts(rule_name, opts)
      end

      parser.on("--without-affected-code",
        "Stop showing affected code while using a default formatter") do
        opts.without_affected_code = true
      end

      parser.on("--no-color", "Disable colors") do
        opts.colors = false
      end

      parser.on("--stdin-filename FILENAME", "Read source from STDIN") do |filename|
        opts.stdin_filename = filename if filename.presence
      end
    end

    opts
  end

  private def config_from_opts(opts)
    config = Config.load(
      root: opts.root,
      path: opts.config,
      skip_reading_config: opts.skip_reading_config?,
    )
    config.autocorrect = opts.autocorrect?
    config.stdin_filename = opts.stdin_filename

    if version = opts.version
      config.version = version
    end
    if globs = opts.globs
      config.globs = globs
    end
    if excluded = opts.excluded
      config.excluded += excluded
    end
    if severity = opts.severity
      config.severity = severity
    end

    configure_formatter(config, opts)
    configure_rules(config, opts)

    config
  end

  private def configure_globs(args, opts) : Nil
    excluded, globs =
      args.partition(&.starts_with?('!'))

    if root = root_path_from_globs(globs)
      opts.root = root
    end
    if globs.present?
      opts.globs = globs
        .map! { |path| path_to_glob(path) }
        .to_set
    end
    if excluded.present?
      opts.excluded = excluded
        .map! { |path| path_to_glob(path.lchop) }
        .to_set
    end
  end

  private def path_to_glob(path : String) : String
    Path[path]
      .expand(home: true)
      .to_posix
      .to_s
  end

  private def root_path_from_globs(globs) : Path?
    dynasty =
      case
      when path = find_as_path(globs, &->File.directory?(String))
        path.parents + [path]
      when path = find_as_path(globs, &->File.file?(String))
        path.parents
      end

    dynasty
      .try &.reverse!
        .find(&->root_path?(Path))
        .try(&.expand(home: true))
  end

  private def find_as_path(globs, &) : Path?
    globs
      .find { |glob| yield glob }
      .try(&->Path.new(String))
  end

  private def root_path?(path : Path) : Bool
    File.exists?(path / Config::Loader::FILENAME) ||
      File.exists?(path / "shard.yml")
  end

  private def configure_rules(config, opts) : Nil
    case
    when only = opts.only
      config.rules.each(&.enabled = false)
      config.update_rules(only, enabled: true)
      # We need to clear the version to ensure that the selected rules
      # are not affected by the version constraint
      config.version = nil
    when opts.all?
      config.rules.each(&.enabled = true)
    end
    if except = opts.except
      config.update_rules(except, enabled: false)
    end
  end

  private def configure_formatter(config, opts) : Nil
    if name = opts.formatter
      config.formatter = name
    end
    config.formatter.config[:autocorrect] = opts.autocorrect?
    config.formatter.config[:without_affected_code] =
      opts.without_affected_code?
  end

  private def configure_describe_opts(rule_name, opts) : Nil
    opts.describe_rule = rule_name.presence
    opts.formatter = :silent
  end

  private def configure_explain_opts(loc, opts) : Nil
    location_to_explain = parse_explain_location(loc)

    filename = location_to_explain.original_filename
    return unless filename

    opts.location_to_explain = location_to_explain
    opts.globs = Set{path_to_glob(filename)}
    opts.formatter = :silent
  end

  private def parse_explain_location(arg)
    Crystal::Location.parse(arg)
  rescue
    raise "location should have PATH:line:column format (e.g., src/file.cr:10:5)"
  end

  private def print_version(output)
    output.puts Ameba.version
  end

  private def print_help(parser, output)
    output.puts parser
  end

  private def describe_rule(rule, output)
    Presenter::RulePresenter.new(output).run(rule)
  end

  private def print_rules(rules, output)
    Presenter::RuleCollectionPresenter.new(output).run(rules)
  end

  private def print_rule_versions(rules, output)
    Presenter::RuleVersionsPresenter.new(output).run(rules)
  end
end
