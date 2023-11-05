module Ameba::Presenter
  private ENABLED_MARK  = "✓".colorize(:green)
  private DISABLED_MARK = "x".colorize(:red)

  class BasePresenter
    # TODO: allow other IOs
    getter output : IO::FileDescriptor | IO::Memory

    def initialize(@output = STDOUT)
    end
  end
end
