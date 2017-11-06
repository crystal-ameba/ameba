require "../src/ameba"
require "benchmark"

private def get_sources(n)
  Dir["src/**/*.cr"].first(n)
end

puts "== Compare:"
Benchmark.ips do |x|
  [
    1,
    3,
    5,
    10,
    20,
    30,
    40,
  ].each do |n|
    sources = get_sources(n)
    formatter = Ameba::Formatter::BaseFormatter.new
    s = n == 1 ? "" : "s"
    x.report("#{n} source#{s}") { Ameba.run sources, formatter }
  end
end

puts "== Measure:"
puts Benchmark.measure { Ameba.run }
