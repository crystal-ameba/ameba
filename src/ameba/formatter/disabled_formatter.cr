module Ameba::Formatter
  # A formatter that shows all disabled lines by inline directives.
  class DisabledFormatter < BaseFormatter
    def finished(sources)
      output << "Disabled rules using inline directives:\n\n"

      sources.each do |source|
        source.issues.select(&.disabled?).each do |issue|
          next unless loc = issue.location

          output << "#{source.path}:#{loc.line_number}".colorize(:cyan)
          output << " #{issue.rule.name}\n"
        end
      end
    end
  end
end
