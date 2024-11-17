module Ameba::Formatter
  class FlycheckFormatter < BaseFormatter
    @mutex = Mutex.new

    def source_finished(source : Source) : Nil
      source.issues.each do |issue|
        next if issue.disabled?
        next if issue.correctable? && config[:autocorrect]?

        next unless loc = issue.location

        @mutex.synchronize do
          output.printf "%s:%d:%d: %s: [%s] %s\n",
            source.path, loc.line_number, loc.column_number, issue.rule.severity.symbol,
            issue.rule.name, issue.message.gsub('\n', " ")
        end
      end
    end
  end
end
