module Ameba::Presenter
  private ENABLED_MARK  = "✓".colorize(:green)
  private DISABLED_MARK = "x".colorize(:red)

  class BasePresenter
    getter output : IO

    def initialize(@output = STDOUT)
    end
  end
end
