require "./util"

module Ameba::Formatter
  # A formatter that shows the detailed explanation of the issue at
  # a specific location.
  class ExplainFormatter
    HEADING = "## "
    PREFIX  = " "

    include Util

    getter output : IO::FileDescriptor | IO::Memory
    getter location : Crystal::Location

    # Creates a new instance of ExplainFormatter.
    # Accepts *output* which indicates the io where the explanation will be wrtitten to.
    # Second argument is *location* which indicates the location to explain.
    #
    # ```
    # ExplainFormatter.new output,
    #   {file: path, line: line_number, column: column_number}
    # ```
    def initialize(@output, location)
      @location = Crystal::Location.new(location[:file], location[:line], location[:column])
    end

    # Reports the explainations at the *@location*.
    def finished(sources)
      source = sources.find(&.path.==(@location.filename))
      return unless source

      issue = source.issues.find(&.location.==(@location))
      return unless issue

      explain(source, issue)
    end

    private def explain(source, issue)
      rule = issue.rule

      location, end_location =
        issue.location, issue.end_location

      return unless location

      output_title "ISSUE INFO"
      output_paragraph [
        issue.message.colorize(:red).to_s,
        location.to_s.colorize(:cyan).to_s,
      ]

      if affected_code = affected_code(source, location, end_location, context_lines: 3)
        output_title "AFFECTED CODE"
        output_paragraph affected_code
      end

      if rule.responds_to?(:description)
        output_title "RULE INFO"
        output_paragraph [rule.severity.to_s, rule.name, rule.description]
      end

      output_title "DETAILED DESCRIPTION"
      output_paragraph(rule.class.parsed_doc || "TO BE DONE...")
    end

    private def output_title(title)
      output << HEADING.colorize(:yellow) << title.colorize(:yellow) << '\n'
      output << '\n'
    end

    private def output_paragraph(paragraph : String)
      output_paragraph(paragraph.lines)
    end

    private def output_paragraph(paragraph : Array(String))
      paragraph.each do |line|
        output << PREFIX << line << '\n'
      end
      output << '\n'
    end
  end
end
