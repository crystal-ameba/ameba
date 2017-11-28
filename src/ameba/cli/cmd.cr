require "../../ameba"
require "option_parser"

# :nodoc:
module Ameba::Cli
  extend self

  private class Opts
    property config : String?
    property silent : Bool = false
    property files : Array(String)?
    property only : Array(String)?
    property except : Array(String)?
  end

  def run(args, opts = Opts.new)
    OptionParser.parse(args) do |parser|
      parser.banner = "Usage: ameba [options] [file1 file2 ...]"

      parser.on("-v", "--version", "Print version") { print_version }
      parser.on("-h", "--help", "Show this help") { show_help parser }
      parser.on("-s", "--silent", "Disable output") { opts.silent = true }
      parser.unknown_args { |f| opts.files = f if f.any? }

      parser.on("-c PATH", "--config PATH", "Specify configuration file") do |f|
        opts.config = f
      end

      parser.on("--only RULE1,RULE2,...", "Specify a list of rules") do |rules|
        opts.only = rules.split ","
      end

      parser.on("--except RULE1,RULE2,...", "Disable the given rules") do |rules|
        opts.except = rules.split ","
      end
    end

    run_ameba opts
  end

  def run_ameba(opts)
    config = Ameba::Config.load opts.config
    config.files = opts.files
    config.formatter = Ameba::Formatter::BaseFormatter.new if opts.silent

    configure_rules(config, opts)

    exit 1 unless Ameba.run(config).success?
  rescue e
    puts "Error: #{e.message}"
    exit 255
  end

  private def configure_rules(config, opts)
    if only = opts.only
      config.rules.map! { |r| r.enabled = false; r }
      only.each do |rule_name|
        config.update_rule(rule_name, enabled: true)
      end
    end

    opts.except.try &.each do |rule_name|
      config.update_rule(rule_name, enabled: false)
    end
  end

  private def print_version
    puts Ameba::VERSION
    exit 0
  end

  private def show_help(parser)
    puts parser
    exit 0
  end
end
