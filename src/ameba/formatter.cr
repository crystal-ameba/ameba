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
      puts "\n\n"
    end

    def report(source)
      print formatter.format source
    end

    def finish(sources)
      puts "\n\n"
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
      String.build do |mes|
        failures = sources.select { |s| s.errors.any? }
        l = failures.map { |f| f.errors.size }.sum

        mes << "#{sources.size} inspected, #{l} failure#{"s" if l != 1}.\n\n"

        failures.each do |failure|
          failure.errors.each do |error|
            mes << "#{failure.path}:#{error.pos}"
            mes << "\n"
            mes << "#{error.rule.name}: #{error.message}\n\n"
          end
        end
      end
    end
  end
end
