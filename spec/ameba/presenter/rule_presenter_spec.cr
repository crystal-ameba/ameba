require "../../spec_helper"

module Ameba
  private def rule_presenter_each_rule(&)
    rules = Config.load.rules

    rules.each do |rule|
      with_presenter(Presenter::RulePresenter, rule) do |presenter, output|
        yield rule, output, presenter
      end
    end
  end

  describe Presenter::RulePresenter do
    it "outputs rule details" do
      rule_presenter_each_rule do |rule, output|
        output.should contain rule.name
        output.should contain rule.severity.to_s

        if description = rule.description
          output.should contain description
        end
      end
    end
  end
end
