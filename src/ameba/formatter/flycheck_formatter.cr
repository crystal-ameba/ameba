module Ameba::Formatter
  class FlycheckFormatter < BaseFormatter
    def source_finished(source : Source)
      source.errors.each do |e|
        next if e.disabled?
        if loc = e.location
          output.printf "%s:%d:%d: %s: [%s] %s\n",
            source.path, loc.line_number, loc.column_number, "E",
            e.rule.name, e.message.gsub("\n", " ")
        end
      end
    end
  end
end
