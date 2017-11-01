require "./ameba/*"
require "./ameba/ast/*"
require "./ameba/rules/*"

module Ameba
  extend self

  abstract struct BaseRule
    abstract def test(source : Source)
  end

  def run(formatter = DotFormatter.new)
    run Dir["**/*.cr"].reject(&.starts_with? "lib/"), formatter
  end

  def run(files, formatter : Formatter)
    sources = files.map { |path| Source.new(File.read(path), path) }

    reporter = Reporter.new formatter
    reporter.start sources
    sources.each do |source|
      catch(source)
      reporter.report source
    end
    reporter.try &.finish sources
    sources
  end

  def catch(source : Source)
    Rule.rules.each do |rule|
      rule.new.test(source)
    end
  end
end
