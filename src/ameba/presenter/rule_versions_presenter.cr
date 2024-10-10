module Ameba::Presenter
  class RuleVersionsPresenter < BasePresenter
    def run(rules, verbose = true)
      missing_version = SemanticVersion.new(0, 0, 0)
      versions = rules
        .sort_by { |rule| rule.since_version || missing_version }
        .group_by(&.since_version)

      first = true

      versions.each do |version, version_rules|
        if verbose
          output.puts unless first
          if version
            output.puts "- %s" % version.to_s.colorize(:green)
          else
            output.puts "- %s" % "N/A".colorize(:dark_gray)
          end
          version_rules.map(&.name).sort!.each do |name|
            output.puts "  - %s" % name.colorize(:dark_gray)
          end
        else
          if version
            output.puts "- %s" % version.to_s.colorize(:green)
          end
        end

        first = false
      end
    end
  end
end
