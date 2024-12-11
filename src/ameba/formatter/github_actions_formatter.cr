require "./util"

module Ameba::Formatter
  # A formatter that outputs issues in a GitHub Actions compatible format.
  #
  # See [GitHub Actions documentation](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/workflow-commands-for-github-actions) for details.
  class GitHubActionsFormatter < BaseFormatter
    include Util

    @started_at : Time::Span?
    @mutex = Mutex.new

    # Reports a message when inspection is started.
    def started(sources) : Nil
      @started_at = Time.monotonic
    end

    # Reports a result of the inspection of a corresponding source.
    def source_finished(source : Source) : Nil
      source.issues.each do |issue|
        next if issue.disabled?

        @mutex.synchronize do
          output << "::"
          output << command_name(issue.rule.severity)
          output << " "
          output << "file="
          output << escape_property(source.path)
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
          output << escape_property(issue.rule.name)
          output << "::"
          output << escape_data(issue.message)
          output << "\n"
        end
      end
    end

    # Reports a message when inspection is finished.
    def finished(sources) : Nil
      return unless step_summary_file = ENV["GITHUB_STEP_SUMMARY"]?

      if started_at = @started_at
        time_elapsed = Time.monotonic - started_at
      end

      File.write(step_summary_file, summary(sources, time_elapsed))
    end

    private def summary(sources, time_elapsed)
      failed_sources = sources.reject(&.valid?)
      total = sources.size
      failures = failed_sources.sum(&.issues.count(&.enabled?))

      String.build do |output|
        output << "## Ameba Results %s\n\n" % {
          failures == 0 ? ":green_heart:" : ":bug:",
        }

        if failures.positive?
          output << "### Issues found:\n\n"

          failed_sources.each do |source|
            issue_count = source.issues.count(&.enabled?)

            if issue_count.positive?
              output << "#### `%s` (**%d** %s)\n\n" % {
                source.path,
                issue_count,
                pluralize(issue_count, "issue"),
              }

              output.puts "| Line | Severity | Name | Message |"
              output.puts "| ---- | -------- | ---- | ------- |"

              source.issues.each do |issue|
                next if issue.disabled?

                output.puts "| %s | %s | %s | %s |" % {
                  issue_location_value(issue) || "-",
                  issue.rule.severity,
                  issue.rule.name,
                  issue.message,
                }
              end
              output << "\n"
            end
          end
          output << "\n"
        end

        if time_elapsed
          output.puts "Finished in %s." % to_human(time_elapsed)
        end
        output.puts "**%d** sources inspected, **%d** %s." % {
          total,
          failures,
          pluralize(failures, "failure"),
        }
        output.puts
        output.puts "> Ameba version: **%s**" % Ameba::VERSION
      end
    end

    private BLOB_URL = begin
      repo = ENV["GITHUB_REPOSITORY"]?
      sha = ENV["GITHUB_SHA"]?

      if repo && sha
        "https://github.com/#{repo}/blob/#{sha}"
      end
    end

    private def issue_location_value(issue)
      location, end_location =
        issue.location, issue.end_location

      return unless location

      line_selector =
        if end_location && location.line_number != end_location.line_number
          "#{location.line_number}-#{end_location.line_number}"
        else
          "#{location.line_number}"
        end

      if BLOB_URL
        location_url = "[%s](%s/%s#%s)" % {
          line_selector,
          BLOB_URL,
          location.filename,
          line_selector
            .split('-')
            .join('-') { |i| "L#{i}" },
        }
      end

      location_url || line_selector
    end

    private def command_name(severity : Severity) : String
      case severity
      in .error?      then "error"
      in .warning?    then "warning"
      in .convention? then "notice"
      end
    end

    # See for details:
    # - https://github.com/actions/toolkit/blob/74906bea83a0dbf6aaba2d00b732deb0c3aefd2d/packages/core/src/command.ts#L92-L97
    # - https://github.com/actions/toolkit/issues/193
    private def escape_data(string : String) : String
      string
        .gsub('%', "%25")
        .gsub('\r', "%0D")
        .gsub('\n', "%0A")
    end

    # See for details:
    # - https://github.com/actions/toolkit/blob/74906bea83a0dbf6aaba2d00b732deb0c3aefd2d/packages/core/src/command.ts#L99-L106
    private def escape_property(string : String) : String
      string
        .gsub('%', "%25")
        .gsub('\r', "%0D")
        .gsub('\n', "%0A")
        .gsub(':', "%3A")
        .gsub(',', "%2C")
    end
  end
end
