require "../../spec_helper"

module Ameba
  private def with_rule_versions_presenter(&)
    rules = Config.load.rules

    with_presenter(Presenter::RuleVersionsPresenter, rules) do |presenter, output|
      yield rules, output, presenter
    end
  end

  describe Presenter::RuleVersionsPresenter do
    it "outputs rule versions" do
      with_rule_versions_presenter do |_rules, output|
        output.should contain <<-TEXT
          - 0.1.0
            - Layout/LineLength
            - Layout/TrailingBlankLines
            - Layout/TrailingWhitespace
            - Lint/ComparisonToBoolean
            - Lint/DebuggerStatement
            - Lint/LiteralInCondition
            - Lint/LiteralInInterpolation
            - Style/UnlessElse
          TEXT
      end
    end
  end
end
