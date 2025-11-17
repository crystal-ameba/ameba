module Ameba::Presenter
  class RulePresenter < BasePresenter
    include Formatter::Util

    def run(rule) : Nil
      output_title "Rule info"

      info = <<-INFO
        Name:           %s
        Severity:       %s
        Enabled:        %s
        Since version:  %s
        INFO

      output_paragraph info % {
        rule.name.colorize(:magenta),
        rule.severity.to_s.colorize(rule.severity.color),
        rule.enabled? ? ENABLED_MARK : DISABLED_MARK,
        (rule.since_version.try(&.to_s) || "N/A").colorize(:white),
      }

      if rule_description = rule.description
        output_title "Description"
        output_paragraph colorize_markdown(rule_description)
      end

      if rule_doc = rule.class.parsed_doc
        output_title "Detailed description"
        output_paragraph colorize_markdown(rule_doc)
      end
    end

    private def output_title(title)
      output.print "### %s\n\n" % title.upcase.colorize(:yellow)
    end

    private def output_paragraph(paragraph : String)
      output_paragraph(paragraph.lines)
    end

    private def output_paragraph(paragraph : Array)
      paragraph.each do |line|
        output.puts "    #{line}"
      end
      output.puts
    end
  end
end
