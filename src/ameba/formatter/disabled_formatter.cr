module Ameba::Formatter
  # A formatter that shows all disabled lines by inline directives.
  class DisabledFormatter < BaseFormatter
    def finished(sources) : Nil
      output << "Disabled rules using inline directives:\n\n"

      sources.each do |source|
        source.issues.each do |issue|
          next unless issue.disabled?
          next unless loc = issue.location

          output << "#{source.path}:#{loc.line_number}".colorize(:cyan)
          output << " #{issue.rule.name}\n"
        end
      end
    end
  end
end
