module Ameba::Presenter
  class RuleVersionsPresenter < BasePresenter
    def run(rules)
      versions =
        rules.compact_map(&.since_version).sort!.uniq!

      versions.each do |version|
        output.puts "- %s" % version.to_s.colorize(:green)
      end
    end
  end
end
