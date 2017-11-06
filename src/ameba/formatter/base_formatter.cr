module Ameba::Formatter
  class BaseFormatter
    # allow other IOs
    getter output : IO::FileDescriptor | IO::Memory

    def initialize(@output = STDOUT)
    end

    def started(sources); end

    def source_finished(source : Source); end

    def source_started(source : Source); end

    def finished(sources); end
  end
end
