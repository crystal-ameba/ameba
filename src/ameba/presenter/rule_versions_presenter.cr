module Ameba::Presenter
  class RuleVersionsPresenter < BasePresenter
    def run(rules, verbose = true)
      missing_version = SemanticVersion.new(0, 0, 0)
      versions = rules
        .sort_by { |rule| rule.since_version || missing_version }
        .group_by(&.since_version)

      if verbose
        versions.each_with_index do |(version, version_rules), idx|
          output.puts if idx.positive?
          if version
            output.puts "- %s" % version.to_s.colorize(:green)
          else
            output.puts "- %s" % "N/A".colorize(:dark_gray)
          end
          version_rules.map(&.name).sort!.each do |name|
            output.puts "  - %s" % name.colorize(:dark_gray)
          end
        end
      else
        versions.each_key do |version|
          if version
            output.puts "- %s" % version.to_s.colorize(:green)
          end
        end
      end
    end
  end
end
