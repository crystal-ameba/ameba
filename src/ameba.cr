require "./ameba/*"
require "./ameba/ast/*"
require "./ameba/rules/*"
require "./ameba/formatter/*"

module Ameba
  extend self

  def run(formatter = Formatter::BaseFormatter.new)
    run Dir["**/*.cr"].reject(&.starts_with? "lib/"), formatter
  end

  def run(files, formatter : Formatter::BaseFormatter)
    sources = files.map { |path| Source.new(File.read(path), path) }

    formatter.started sources
    sources.each do |source|
      formatter.source_started source
      catch(source)
      formatter.source_finished source
    end
    formatter.finished sources
    sources
  end

  def catch(source : Source)
    Rule.rules.each do |rule|
      rule.new.test(source)
    end
  end
end
