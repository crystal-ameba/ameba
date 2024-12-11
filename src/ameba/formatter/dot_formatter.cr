require "./util"

module Ameba::Formatter
  # A formatter that shows a progress of inspection in a terminal using dots.
  # It is similar to Crystal's dot formatter for specs.
  class DotFormatter < BaseFormatter
    include Util

    @started_at : Time::Span?
    @mutex = Mutex.new

    # Reports a message when inspection is started.
    def started(sources) : Nil
      @started_at = Time.monotonic

      output.puts started_message(sources.size)
      output.puts
    end

    # Reports a result of the inspection of a corresponding source.
    def source_finished(source : Source) : Nil
      sym = source.valid? ? ".".colorize(:green) : "F".colorize(:red)
      @mutex.synchronize { output << sym }
    end

    # Reports a message when inspection is finished.
    def finished(sources) : Nil
      output.flush
      output << "\n\n"

      show_affected_code = !config[:without_affected_code]?
      failed_sources = sources.reject &.valid?

      failed_sources.each do |source|
        source.issues.each do |issue|
          next if issue.disabled?
          next if (location = issue.location).nil?

          output.print location.colorize(:cyan)
          if issue.correctable?
            if config[:autocorrect]?
              output.print " [Corrected]".colorize(:green)
            else
              output.print " [Correctable]".colorize(:yellow)
            end
          end
          output.puts
          output.puts ("[%s] %s: %s" % {
            issue.rule.severity.symbol,
            issue.rule.name,
            issue.message,
          }).colorize(issue.rule.severity.color)

          if show_affected_code && (code = affected_code(issue))
            output << code.colorize(:default)
          end

          output.puts
        end
      end

      output.puts finished_in_message(@started_at, Time.monotonic)
      output.puts final_message(sources, failed_sources)
    end

    private def started_message(size)
      if size == 1
        "Inspecting 1 file".colorize(:default)
      else
        "Inspecting #{size} files".colorize(:default)
      end
    end

    private def finished_in_message(started, finished)
      return unless started && finished

      "Finished in #{to_human(finished - started)}".colorize(:default)
    end

    private def final_message(sources, failed_sources)
      total = sources.size
      failures = failed_sources.sum(&.issues.count(&.enabled?))
      color = failures == 0 ? :green : :red

      "#{total} inspected, #{failures} #{pluralize(failures, "failure")}".colorize(color)
    end
  end
end
