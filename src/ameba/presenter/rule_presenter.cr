module Ameba::Presenter
  class RulePresenter < BasePresenter
    def run(rule) : Nil
      output.puts
      output_title "Rule info"
      output_paragraph "%s of a %s severity [enabled: %s]" % {
        rule.name.colorize(:magenta),
        rule.severity.to_s.colorize(rule.severity.color),
        rule.enabled? ? ENABLED_MARK : DISABLED_MARK,
      }
      if rule_description = colorize_code_fences(rule.description)
        output_paragraph rule_description
      end

      if rule_doc = colorize_code_fences(rule.class.parsed_doc)
        output_title "Detailed description"
        output_paragraph rule_doc
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

    private def colorize_code_fences(string)
      return unless string
      string
        .gsub(/```(.+?)```/m, &.colorize(:dark_gray))
        .gsub(/`(?!`)(.+?)`/, &.colorize(:dark_gray))
    end
  end
end
