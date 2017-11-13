require "option_parser"
require "./ameba"

files, formatter, config_path = nil, nil, nil

OptionParser.parse(ARGV) do |parser|
  parser.banner = "Usage: ameba [options] [file1 file2 ...]"

  parser.on("-v", "--version", "Print version") do
    puts Ameba::VERSION
    exit 0
  end

  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit 0
  end

  parser.on("-s", "--silent", "Disable output") do
    formatter = Ameba::Formatter::BaseFormatter.new
  end

  # parser.on("-f FORMATTER", "--format FORMATTER", "Specify formatter") do |f|
  # end

  parser.on("-c PATH", "--config PATH", "Specify configuration file") do |f|
    config_path = f
  end

  parser.unknown_args do |f|
    files = f if f.any?
  end
end

config = Ameba::Config.load config_path
config.formatter = formatter
config.files = files

exit(1) unless Ameba.run(config).success?
