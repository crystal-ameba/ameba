require "./ameba/*"
require "./ameba/rule/*"

module Ameba
  extend self

  RULES = [
    Rule::LineLength,
  ]

  def run
    run Dir["**/*.cr"]
  end

  def run(files)
    files.each do |path|
      catch Source.new(File.read path)
    end
  end

  def catch(source : Source)
    RULES.each do |rule|
      rule.new.test(source)
    end
  end
end
