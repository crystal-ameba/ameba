require "../../ameba"
require "option_parser"

# :nodoc:
module Ameba::Cli
  extend self

  def run(args)
    opts = parse_args args
    config = Config.load opts.config
    config.files = opts.files

    configure_formatter(config, opts)
    configure_rules(config, opts)

    exit 1 unless Ameba.run(config).success?
  rescue e
    puts "Error: #{e.message}"
    exit 255
  end

  private class Opts
    property config = Config::PATH
    property formatter : Symbol | String | Nil
    property files : Array(String)?
    property only : Array(String)?
    property except : Array(String)?
    property? all = false
  end

  def parse_args(args, opts = Opts.new)
    OptionParser.parse(args) do |parser|
      parser.banner = "Usage: ameba [options] [file1 file2 ...]"

      parser.on("-v", "--version", "Print version") { print_version }
      parser.on("-h", "--help", "Show this help") { show_help parser }
      parser.on("-s", "--silent", "Disable output") { opts.formatter = :silent }
      parser.unknown_args { |f| opts.files = f if f.any? }

      parser.on("-c", "--config PATH",
        "Specify a configuration file") do |path|
        opts.config = path
      end

      parser.on("-f", "--format FORMATTER",
        "Choose an output formatter: #{Config.formatter_names}") do |formatter|
        opts.formatter = formatter
      end

      parser.on("--only RULE1,RULE2,...",
        "Run only given rules (or groups)") do |rules|
        opts.only = rules.split ","
      end

      parser.on("--except RULE1,RULE2,...",
        "Disable the given rules (or groups)") do |rules|
        opts.except = rules.split ","
      end

      parser.on("--all", "Enables all available rules") do
        opts.all = true
      end

      parser.on("--gen-config",
        "Generate a configuration file acting as a TODO list") do
        opts.formatter = :todo
        opts.config = ""
      end
    end

    opts
  end

  private def configure_rules(config, opts)
    if only = opts.only
      config.rules.map! { |r| r.enabled = false; r }
      config.update_rules(only, enabled: true)
    elsif opts.all?
      config.rules.map! { |r| r.enabled = true; r }
    end

    config.update_rules(opts.except, enabled: false)
  end

  private def configure_formatter(config, opts)
    if name = opts.formatter
      config.formatter = name
    end
  end

  private def print_version
    puts VERSION
    exit 0
  end

  private def show_help(parser)
    puts parser
    exit 0
  end
end
