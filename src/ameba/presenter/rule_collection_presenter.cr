module Ameba::Presenter
  class RuleCollectionPresenter < BasePresenter
    def run(rules) : Nil
      rules = rules.to_h do |rule|
        name = rule.name.split('/')
        name = "%s/%s" % {
          name[0...-1].join('/').colorize(:light_gray),
          name.last.colorize(:white),
        }
        {name, rule}
      end
      longest_name = rules.max_of(&.first.size)

      rules.group_by(&.last.group).each do |group, group_rules|
        output.puts "— %s" % group.colorize(:light_blue).underline
        output.puts
        group_rules.each do |name, rule|
          output.puts "  %s  [%s]    %s    %s" % {
            rule.enabled? ? ENABLED_MARK : DISABLED_MARK,
            rule.severity.symbol.to_s.colorize(:green),
            name.ljust(longest_name),
            rule.description.colorize(:dark_gray),
          }
        end
        output.puts
      end

      output.puts "Total rules: %s / %s enabled" % {
        rules.size.to_s.colorize(:light_blue),
        rules.count(&.last.enabled?).to_s.colorize(:light_blue),
      }
    end
  end
end
