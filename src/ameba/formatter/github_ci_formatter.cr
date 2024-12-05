module Ameba::Formatter
  class GitHubCIFormatter < BaseFormatter
    def source_finished(source : Source) : Nil
      source.issues.each do |issue|
        next unless loc = issue.location
        end_loc = issue.end_location || loc

        output << "::"
        output << command_name(issue.rule.severity)
        output << " "
        output << "file="
        output << source.path
        output << ",line="
        output << loc.line_number
        output << ",endLine="
        output << end_loc.line_number
        output << ",col="
        output << loc.column_number
        output << ",endColumn="
        output << end_loc.column_number
        output << ",title="
        output << issue.rule.name
        output << "::"
        output << issue.message.gsub("\n", "\\n")
        output << "\n"
      end
    end

    private def command_name(severity : Severity) : String
      case severity
      in .error?
        "error"
      in .warning?
        "warning"
      in .convention?
        "notice"
      end
    end
  end
end
