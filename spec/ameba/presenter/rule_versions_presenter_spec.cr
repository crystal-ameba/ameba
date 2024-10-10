require "../../spec_helper"

module Ameba
  private def with_rule_versions_presenter(&)
    with_presenter(Presenter::RuleVersionsPresenter) do |presenter, io|
      rules = Config.load.rules
      presenter.run(rules)

      output = io.to_s
      output = Formatter::Util.deansify(output).to_s

      yield rules, output, presenter
    end
  end

  describe Presenter::RuleVersionsPresenter do
    it "outputs rule versions" do
      with_rule_versions_presenter do |rules, output|
        missing_version = SemanticVersion.new(0, 0, 0)
        versions = rules
          .sort_by { |rule| rule.since_version || missing_version }
          .group_by(&.since_version)

        versions.each do |version, version_rules|
          output.should contain (version || "N/A").to_s

          version_rules.map(&.name).each do |name|
            output.should contain name
          end
        end
      end
    end
  end
end
