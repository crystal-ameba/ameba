module Ameba
  abstract class Formatter
    abstract def before(sources)
    abstract def format(source : Source)
    abstract def after(sources)
  end

  class Reporter
    property formatter : Formatter

    def initialize(@formatter : Formatter)
    end

    def start(sources)
      puts formatter.before sources
    end

    def report(source)
      print formatter.format source
    end

    def finish(sources)
      puts
      puts formatter.after sources
    end
  end

  class DotFormatter < Formatter
    def before(sources)
      if (len = sources.size) == 1
        "Inspecting 1 file."
      else
        "Inspecting #{len} files."
      end
    end

    def format(source : Source)
      source.errors.size == 0 ? "." : "F"
    end

    def after(sources)
      "Done!"
    end
  end
end
