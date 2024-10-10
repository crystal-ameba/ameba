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
