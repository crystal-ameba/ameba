require "../../spec_helper"

module Ameba
  private def with_rule_collection_presenter(&)
    rules = Config.load.rules

    with_presenter(Presenter::RuleCollectionPresenter, rules) do |presenter, output|
      yield rules, output, presenter
    end
  end

  describe Presenter::RuleCollectionPresenter do
    it "outputs rule collection details" do
      with_rule_collection_presenter do |rules, output|
        rules.each do |rule|
          output.should contain rule.name
          output.should contain rule.severity.symbol

          if description = rule.description
            output.should contain description
          end
        end
        output.should contain "Total rules: #{rules.size}"
        output.should match /\d+ enabled/
      end
    end
  end
end
