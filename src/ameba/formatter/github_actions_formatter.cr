module Ameba::Formatter
  # A formatter that outputs issues in a GitHub Actions compatible format.
  #
  # See [GitHub Actions documentation](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/workflow-commands-for-github-actions) for details.
  class GitHubActionsFormatter < BaseFormatter
    @mutex = Mutex.new

    # Reports a result of the inspection of a corresponding source.
    def source_finished(source : Source) : Nil
      source.issues.each do |issue|
        next if issue.disabled?

        @mutex.synchronize do
          output << "::"
          output << command_name(issue.rule.severity)
          output << " "
          output << "file="
          output << source.path
          if location = issue.location
            output << ",line="
            output << location.line_number
            output << ",col="
            output << location.column_number
          end
          if end_location = issue.end_location
            output << ",endLine="
            output << end_location.line_number
            output << ",endColumn="
            output << end_location.column_number
          end
          output << ",title="
          output << issue.rule.name
          output << "::"
          output << issue.message.gsub('\n', "\\n")
          output << "\n"
        end
      end
    end

    private def command_name(severity : Severity) : String
      case severity
      in .error?      then "error"
      in .warning?    then "warning"
      in .convention? then "notice"
      end
    end
  end
end
