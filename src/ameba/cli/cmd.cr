require "option_parser"
require "../../ameba"

# :nodoc:
module Ameba::CLI
  extend self

  private class Opts
    property config : Path?
    property version : String?
    property formatter : Symbol | String | Nil
    property root : Path?
    property globs : Set(String)?
    property excluded : Set(String)?
    property only : Set(String)?
    property except : Set(String)?
    property describe_rule : String?
    property location_to_explain : NamedTuple(file: String, line: Int32, column: Int32)?
    property fail_level : Severity?
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

  def run(args = ARGV) : Bool
    opts = parse_args(args)

    Colorize.enabled = opts.colors?

    if (location_to_explain = opts.location_to_explain) && opts.autocorrect?
      raise "Invalid usage: Cannot explain an issue and autocorrect at the same time."
    end

    if opts.stdin_filename && opts.autocorrect?
      raise "Invalid usage: Cannot autocorrect from stdin."
    end

    config = config_from_opts(opts)

    if opts.rules?
      print_rules(config.rules)
      return true
    end

    if opts.rule_versions?
      print_rule_versions(config.rules)
      return true
    end

    if describe_rule_name = opts.describe_rule
      unless rule = config.rules.find(&.name.== describe_rule_name)
        raise "Unknown rule"
      end
      describe_rule(rule)
      return true
    end

    runner = Ameba.run(config)

    if location_to_explain
      runner.explain(location_to_explain)
      return true
    end

    runner.success?
  rescue ex : ExitException
    ex.code.zero?
  end

  def parse_args(args, opts = Opts.new)
    OptionParser.parse(args) do |parser|
      parser.banner = "Usage: ameba [options] [file1 file2 ...]"

      parser.on("-v", "--version", "Print version") do
        print_version
        raise ExitException.new
      end
      parser.on("-h", "--help", "Show this help") do
        print_help(parser)
        raise ExitException.new
      end
      parser.on("-r", "--rules", "Show all available rules") { opts.rules = true }
      parser.on("-R", "--rule-versions", "Show all available rule versions") { opts.rule_versions = true }
      parser.on("-s", "--silent", "Disable output") { opts.formatter = :silent }
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

      parser.on("-c", "--config PATH",
        "Specify a configuration file") do |path|
        opts.config = Path[path] unless path.empty?
      end

      parser.on("-u", "--up-to-version VERSION",
        "Choose a version") do |version|
        opts.version = version
      end

      parser.on("-f", "--format FORMATTER",
        "Choose an output formatter: #{Config.formatter_names}") do |formatter|
        opts.formatter = formatter
      end

      parser.on("--only RULE1,RULE2,...",
        "Run only given rules (or groups)") do |rules|
        opts.only = rules.split(',').to_set
      end

      parser.on("--except RULE1,RULE2,...",
        "Disable the given rules (or groups)") do |rules|
        opts.except = rules.split(',').to_set
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

      parser.on("--fail-level SEVERITY",
        "Change the level of failure to exit. Defaults to Convention") do |level|
        opts.fail_level = Severity.parse(level)
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

      parser.on("--stdin-filename FILENAME", "Read source from STDIN") do |file|
        opts.stdin_filename = file
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
    if fail_level = opts.fail_level
      config.severity = fail_level
    end

    configure_formatter(config, opts)
    configure_rules(config, opts)

    config
  end

  private def configure_globs(args, opts) : Nil
    excluded, globs =
      args.partition(&.starts_with?('!'))

    root = root_path_from_globs(globs)
    root ||= Path[Dir.current]

    if globs.present?
      opts.globs = globs
        .map! { |path| path_to_glob(path, root) }
        .to_set
    end
    if excluded.present?
      opts.excluded = excluded
        .map! { |path| path_to_glob(path.lchop, root) }
        .to_set
    end
    opts.root = root
  end

  private def path_to_glob(path : String, root : Path) : String
    base = glob?(path) ? root : Dir.current

    Path[path]
      .expand(base, home: true)
      .to_posix
      .to_s
  end

  private def glob?(string : String) : Bool
    string.each_char.any?(&.in?('*', '?', '[', ']', '{', '}'))
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
    File.exists?(path / Config::FILENAME) ||
      File.exists?(path / "shard.yml")
  end

  private def configure_rules(config, opts) : Nil
    case
    when only = opts.only
      config.rules.each(&.enabled = false)
      config.update_rules(only, enabled: true)
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
    opts.location_to_explain = location_to_explain
    opts.globs = Set{location_to_explain[:file]}
    opts.formatter = :silent
  end

  private def parse_explain_location(arg)
    location = arg.split(':', remove_empty: true).map! &.strip
    raise ArgumentError.new unless location.size === 3

    file, line, column = location
    {
      file:   file,
      line:   line.to_i,
      column: column.to_i,
    }
  rescue
    raise "location should have PATH:line:column format"
  end

  private def print_version
    if GIT_SHA
      puts "%s [%s]" % {VERSION, GIT_SHA}
    else
      puts VERSION
    end
  end

  private def print_help(parser)
    puts parser
  end

  private def describe_rule(rule)
    Presenter::RulePresenter.new.run(rule)
  end

  private def print_rules(rules)
    Presenter::RuleCollectionPresenter.new.run(rules)
  end

  private def print_rule_versions(rules)
    Presenter::RuleVersionsPresenter.new.run(rules)
  end
end
