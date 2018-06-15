require "../spec_helper"

module Ameba
  private def runner(files = [__FILE__], formatter = DummyFormatter.new)
    config = Config.load
    config.formatter = formatter
    config.files = files

    config.update_rule ErrorRule.rule_name, enabled: false

    Runner.new(config)
  end

  describe Runner do
    formatter = DummyFormatter.new

    describe "#run" do
      it "returns self" do
        runner.run.should_not be_nil
      end

      it "calls started callback" do
        runner(formatter: formatter).run
        formatter.started_sources.should_not be_nil
      end

      it "calls finished callback" do
        runner(formatter: formatter).run
        formatter.finished_sources.should_not be_nil
      end

      it "calls source_started callback" do
        runner(formatter: formatter).run
        formatter.started_source.should_not be_nil
      end

      it "calls source_finished callback" do
        runner(formatter: formatter).run
        formatter.finished_source.should_not be_nil
      end

      it "skips rule check if source is excluded" do
        path = "source.cr"
        source = Source.new "", path

        all_rules = ([] of Rule::Base).tap do |rules|
          rule = ErrorRule.new
          rule.excluded = [path]
          rules << rule
        end

        Runner.new(all_rules, [source], formatter).run.success?.should be_true
      end

      context "invalid syntax" do
        it "reports a syntax error" do
          rules = [Rule::Lint::Syntax.new] of Rule::Base
          source = Source.new "def bad_syntax"

          Runner.new(rules, [source], formatter).run
          source.should_not be_valid
          source.issues.first.rule.name.should eq Rule::Lint::Syntax.rule_name
        end

        it "does not run other rules" do
          rules = [Rule::Lint::Syntax.new, Rule::Style::ConstantNames.new] of Rule::Base
          source = Source.new %q(
              MyBadConstant = 1

              when my_bad_syntax
          )

          Runner.new(rules, [source], formatter).run
          source.should_not be_valid
          source.issues.size.should eq 1
        end
      end

      context "unneeded disables" do
        it "reports an issue if such disable exists" do
          rules = [Rule::Lint::UnneededDisableDirective.new] of Rule::Base
          source = Source.new %(
            a = 1 # ameba:disable LineLength
          )

          Runner.new(rules, [source], formatter).run
          source.should_not be_valid
          source.issues.first.rule.name.should eq Rule::Lint::UnneededDisableDirective.rule_name
        end
      end
    end

    describe "#success?" do
      it "returns true if runner has not been run" do
        runner.success?.should be_true
      end

      it "returns true if all sources are valid" do
        runner.run.success?.should be_true
      end

      it "returns false if there are invalid sources" do
        rules = Rule.rules.map &.new.as(Rule::Base)
        s = Source.new %q(
          WrongConstant = 5
        )
        Runner.new(rules, [s], formatter).run.success?.should be_false
      end
    end
  end
end
