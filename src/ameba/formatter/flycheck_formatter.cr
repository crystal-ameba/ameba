module Ameba::Formatter
  class FlycheckFormatter < BaseFormatter
    def source_finished(source : Source)
      source.issues.each do |e|
        next if e.disabled?
        if loc = e.location
          output.printf "%s:%d:%d: %s: [%s] %s\n",
            source.path, loc.line_number, loc.column_number, e.rule.severity.symbol,
            e.rule.name, e.message.gsub("\n", " ")
        end
      end
    end
  end
end
