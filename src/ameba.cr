require "./ameba/*"
require "./ameba/ast/*"
require "./ameba/rule/*"
require "./ameba/formatter/*"

module Ameba
  extend self

  def run(config = Config.load)
    Runner.new(config).run
  end
end
