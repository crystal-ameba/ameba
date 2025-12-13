require "./util"

module Ameba::Formatter
  # A formatter that shows a progress of inspection in a terminal using dots.
  # It is similar to Crystal's dot formatter for specs.
  class DotFormatter < BaseFormatter
    include Util

    @started_at : Time::Span?
    @inspected_sources_no = 0
    @mutex = Mutex.new

    # Reports a message when inspection is started.
    def started(sources) : Nil
      @started_at = Time.monotonic
      @inspected_sources_no = 0

      output.puts started_message(sources.size)
      output.puts
    end

    # Reports a result of the inspection of a corresponding source.
    def source_finished(source : Source) : Nil
      sym = source.valid? ? ".".colorize(:green) : "F".colorize(:red)
      @mutex.synchronize do
        @inspected_sources_no += 1
        output << sym
      end
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
      "Inspecting #{size} #{pluralize(size, "file")}"
    end

    private def finished_in_message(started, finished)
      return unless started && finished

      "Finished in #{to_human(finished - started)}".colorize(:default)
    end

    private def final_message(sources, failed_sources)
      failures = failed_sources.sum(&.issues.count(&.enabled?))
      color = failures == 0 ? :green : :red

      message = "%d inspected, %d %s" % {
        @inspected_sources_no,
        failures,
        pluralize(failures, "failure"),
      }
      message.colorize(color)
    end
  end
end
