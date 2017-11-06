require "option_parser"
require "./ameba"

formatter = Ameba::Formatter::DotFormatter

OptionParser.parse(ARGV) do |parser|
  parser.banner = "Usage: ameba [options]"

  parser.on("-v", "--version", "Print version") do
    puts Ameba::VERSION
    exit 0
  end

  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit 0
  end

  parser.on("-s", "--silent", "Disable output") do
    formatter = Ameba::Formatter::BaseFormatter
  end
end

files = Dir["**/*.cr"]

exit(1) unless Ameba.run(files, formatter.new).all? &.valid?
