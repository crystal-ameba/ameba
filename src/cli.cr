require "option_parser"
require "./ameba"

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
end

sources = Ameba.run
failed = sources.any? { |s| !s.valid? }
exit(-1) if failed
