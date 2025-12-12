require "./util"

module Ameba::Formatter
  # A formatter that shows the detailed explanation of the issue at
  # a specific location.
  class ExplainFormatter
    include Util

    getter output : IO::FileDescriptor | IO::Memory
    getter location : Crystal::Location

    # Creates a new instance of `ExplainFormatter`.
    #
    # Accepts *output* which indicates the io where the explanation will be written to.
    # Second argument is *location* which indicates the location to explain.
    #
    # ```
    # ExplainFormatter.new output, {
    #   file:   path,
    #   line:   line_number,
    #   column: column_number,
    # }
    # ```
    def initialize(@output, @location)
    end

    # Reports the explanations at the *@location*.
    def finished(sources) : Nil
      source = sources.find(&.path.==(@location.filename))
      return unless source

      issue = source.issues.find(&.location.==(@location))
      return unless issue

      explain(source, issue)
    end

    private def explain(source, issue) : Nil
      return unless location = issue.location

      output << '\n'
      output_title "Issue info"
      output_paragraph [
        issue.message.colorize(:red),
        location.to_s.colorize(:cyan),
      ]

      if affected_code = affected_code(issue, context_lines: 3)
        output_title "Affected code"
        output_paragraph affected_code
      end

      rule = issue.rule

      output_title "Rule info"
      output_paragraph "%s of a %s severity" % {
        rule.name.colorize(:magenta),
        rule.severity.to_s.colorize(rule.severity.color),
      }
      if rule_description = rule.description
        output_paragraph colorize_markdown(rule_description)
      end

      if rule_doc = rule.class.parsed_doc
        output_title "Detailed description"
        output_paragraph colorize_markdown(rule_doc)
      end
    end

    private def output_title(title)
      output << "### ".colorize(:yellow)
      output << title.upcase.colorize(:yellow)
      output << "\n\n"
    end

    private def output_paragraph(paragraph : String)
      output_paragraph(paragraph.lines)
    end

    private def output_paragraph(paragraph : Array)
      paragraph.each do |line|
        output << "    " << line << '\n'
      end
      output << '\n'
    end
  end
end
