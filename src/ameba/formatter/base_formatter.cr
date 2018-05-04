# A module that utilizes Ameba's formatters.
module Ameba::Formatter
  # A base formatter for all formatters. It uses `output` IO
  # to report results and also implements stub methods for
  # callbacks in `Ameba::Runner#run` method.
  class BaseFormatter
    # TODO: allow other IOs
    getter output : IO::FileDescriptor | IO::Memory

    def initialize(@output = STDOUT)
    end

    # Callback that indicates when inspecting is started.
    # A list of sources to inspect is passed as an argument.
    def started(_sources); end

    # Callback that indicates when source inspection is finished.
    # A corresponding source is passed as an argument.
    def source_finished(_source : Source); end

    # Callback that indicates when source inspection is finished.
    # A corresponding source is passed as an argument.
    def source_started(_source : Source); end

    # Callback that indicates when inspection is finished.
    # A list of inspected sources is passed as an argument.
    def finished(_sources); end
  end
end
