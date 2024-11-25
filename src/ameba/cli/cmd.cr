require "../../ameba"
require "option_parser"

# :nodoc:
module Ameba::Cli
  extend self

  # ameba:disable Metrics/CyclomaticComplexity
  def run(args = ARGV) : Nil
    opts = parse_args args
    location_to_explain = opts.location_to_explain
    stdin_filename = opts.stdin_filename
    autocorrect = opts.autocorrect?

    if location_to_explain && autocorrect
      raise "Invalid usage: Cannot explain an issue and autocorrect at the same time."
    end

    if stdin_filename && autocorrect
      raise "Invalid usage: Cannot autocorrect from stdin."
    end

    config = Config.load opts.config, opts.colors?, opts.skip_reading_config?
    config.autocorrect = autocorrect
    config.stdin_filename = stdin_filename

    if globs = opts.globs
      config.globs = globs
    end
    if fail_level = opts.fail_level
      config.severity = fail_level
    end

    configure_formatter(config, opts)
    configure_rules(config, opts)

    if opts.rules?
      print_rules(config.rules)
    end

    if describe_rule_name = opts.describe_rule
      unless rule = config.rules.find(&.name.== describe_rule_name)
        raise "Unknown rule"
      end
      describe_rule(rule)
    end

    runner = Ameba.run(config)

    if location_to_explain
      runner.explain(location_to_explain)
    else
      exit 1 unless runner.success?
    end
  rescue e
    puts "Error: #{e.message}"
    exit 255
  end

  private class Opts
    property config : Path?
    property formatter : Symbol | String | Nil
    property globs : Array(String)?
    property only : Array(String)?
    property except : Array(String)?
    property describe_rule : String?
    property location_to_explain : NamedTuple(file: String, line: Int32, column: Int32)?
    property fail_level : Severity?
    property stdin_filename : String?
    property? skip_reading_config = false
    property? rules = false
    property? all = false
    property? colors = true
    property? without_affected_code = false
    property? autocorrect = false
  end

  def parse_args(args, opts = Opts.new)
    OptionParser.parse(args) do |parser|
      parser.banner = "Usage: ameba [options] [file1 file2 ...]"

      parser.on("-v", "--version", "Print version") { print_version }
      parser.on("-h", "--help", "Show this help") { print_help(parser) }
      parser.on("-r", "--rules", "Show all available rules") { opts.rules = true }
      parser.on("-s", "--silent", "Disable output") { opts.formatter = :silent }
      parser.unknown_args do |arr|
        case
        when arr.size == 1 && arr.first == "-"
          opts.stdin_filename = arr.first
        when arr.size == 1 && arr.first.matches?(/.+:\d+:\d+/)
          configure_explain_opts(arr.first, opts)
        else
          opts.globs = arr unless arr.empty?
        end
      end

      parser.on("-c", "--config PATH",
        "Specify a configuration file") do |path|
        opts.config = Path[path] unless path.empty?
      end

      parser.on("-f", "--format FORMATTER",
        "Choose an output formatter: #{Config.formatter_names}") do |formatter|
        opts.formatter = formatter
      end

      parser.on("--only RULE1,RULE2,...",
        "Run only given rules (or groups)") do |rules|
        opts.only = rules.split(',')
      end

      parser.on("--except RULE1,RULE2,...",
        "Disable the given rules (or groups)") do |rules|
        opts.except = rules.split(',')
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

  private def configure_rules(config, opts) : Nil
    case
    when only = opts.only
      config.rules.each(&.enabled = false)
      config.update_rules(only, enabled: true)
    when opts.all?
      config.rules.each(&.enabled = true)
    end
    config.update_rules(opts.except, enabled: false)
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
    opts.globs = [location_to_explain[:file]]
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
    puts VERSION
    exit 0
  end

  private def print_help(parser)
    puts parser
    exit 0
  end

  private def describe_rule(rule)
    Presenter::RulePresenter.new.run(rule)
    exit 0
  end

  private def print_rules(rules)
    Presenter::RuleCollectionPresenter.new.run(rules)
    exit 0
  end
end
