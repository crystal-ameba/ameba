require "../spec_helper"

module Ameba
  private def runner(files = [__FILE__], formatter = DummyFormatter.new)
    config = Config.load(skip_reading_config: true)
    config.formatter = formatter
    config.globs = files.to_set

    config.update_rule(VersionedRule.rule_name, enabled: false)
    config.update_rule(ErrorRule.rule_name, enabled: false)
    config.update_rule(PerfRule.rule_name, enabled: false)
    config.update_rule(AtoAA.rule_name, enabled: false)
    config.update_rule(AtoB.rule_name, enabled: false)
    config.update_rule(BtoA.rule_name, enabled: false)
    config.update_rule(BtoC.rule_name, enabled: false)
    config.update_rule(CtoA.rule_name, enabled: false)
    config.update_rule(ClassToModule.rule_name, enabled: false)
    config.update_rule(ModuleToClass.rule_name, enabled: false)

    Runner.new(config)
  end

  describe Runner do
    formatter = DummyFormatter.new
    default_severity = Severity::Convention

    describe "#run" do
      it "returns self" do
        runner.run.should be_a(Runner)
      end

      context "invokes hooks" do
        before_each do
          runner(formatter: formatter).run
        end

        it "calls started callback" do
          formatter.started_sources.should_not be_nil
        end

        it "calls finished callback" do
          formatter.finished_sources.should_not be_nil
        end

        it "calls source_started callback" do
          formatter.started_source.should_not be_nil
        end

        it "calls source_finished callback" do
          formatter.finished_source.should_not be_nil
        end
      end

      it "checks accordingly to the rule #since_version" do
        rules = [VersionedRule.new] of Rule::Base
        source = Source.new(path: "source.cr")

        v1_0_0 = SemanticVersion.parse("1.0.0")
        Runner.new(rules, [source], formatter, default_severity, false, v1_0_0).run.success?.should be_true

        v1_5_0 = SemanticVersion.parse("1.5.0")
        Runner.new(rules, [source], formatter, default_severity, false, v1_5_0).run.success?.should be_false

        v1_10_0 = SemanticVersion.parse("1.10.0")
        Runner.new(rules, [source], formatter, default_severity, false, v1_10_0).run.success?.should be_false
      end

      it "skips rules based on severity" do
        rules = [ErrorRule.new] of Rule::Base

        Source.new.tap do |source|
          Runner.new(rules, [source], formatter, :convention).run
          source.issues.size.should eq(1)
        end

        Source.new.tap do |source|
          Runner.new(rules, [source], formatter, :warning).run
          source.issues.should be_empty
        end
      end

      it "skips rule check if source is excluded" do
        path = "source.cr"
        source = Source.new(path: path)

        all_rules = ([] of Rule::Base).tap do |rules|
          rule = ErrorRule.new
          rule.excluded = Set{path}
          rules << rule
        end

        Runner.new(all_rules, [source], formatter, default_severity).run.success?.should be_true
      end

      it "aborts because of an infinite loop" do
        rules = [AtoAA.new] of Rule::Base
        source = Source.new("class A; end", "source.cr")
        message = "Infinite loop in source.cr caused by Ameba/AtoAA"

        expect_raises(Runner::InfiniteCorrectionLoopError, message) do
          Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run
        end
      end

      it "corrects `return(a)if b` once it has been formatted" do
        rules = [Rule::Lint::Formatting.new, Rule::Style::RedundantReturn.new] of Rule::Base
        path = File.tempname("source", ".cr")
        code = "def foo(a, b)\n  return(a)if b\nend\n"
        File.write(path, code)
        source = Source.new(code, path)

        begin
          Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run
          source.code.should eq "def foo(a, b)\n  a if b\nend\n"
        ensure
          File.delete(path) rescue nil
        end
      end

      context "exception in rule" do
        it "raises an exception raised in fiber while running a rule" do
          rule = RaiseRule.new
          rule.should_raise = true
          rules = [rule] of Rule::Base
          source = Source.new(path: "source.cr")

          expect_raises(Exception, "something went wrong") do
            Runner.new(rules, [source], formatter, default_severity).run
          end
        end
      end

      context "issues sorting" do
        it "sorts issues by severity, line number, and column number" do
          rules = [
            ErrorRule.from_yaml("{ Severity: convention, Message: foo }"),
            ErrorRule.from_yaml("{ Severity: convention, Message: bar, LineNumber: 2 }"),
            ErrorRule.from_yaml("{ Severity: warning, Message: baz, LineNumber: 2 }"),
            ErrorRule.from_yaml("{ Severity: error, Message: bat, LineNumber: 2 }"),
            ErrorRule.from_yaml("{ Severity: warning, Message: baq }"),
          ] of Rule::Base
          source = Source.new("foo\nbar")

          Runner.new(rules, [source], formatter, default_severity).run
          source.should_not be_valid
          source.issues.map(&.message).should eq %w[foo baq bar baz bat]
        end
      end

      context "invalid syntax" do
        it "reports a syntax error" do
          rules = [Rule::Lint::Syntax.new] of Rule::Base
          source = Source.new("def bad_syntax")

          Runner.new(rules, [source], formatter, default_severity).run
          source.should_not be_valid
          source.issues.first.rule.should be_a Rule::Lint::Syntax
        end

        it "does not run other rules" do
          rules = [Rule::Lint::Syntax.new, Rule::Naming::ConstantNames.new]
          source = Source.new <<-CRYSTAL
            MyBadConstant = 1

            when my_bad_syntax
            CRYSTAL

          Runner.new(rules, [source], formatter, default_severity).run
          source.should_not be_valid
          source.issues.size.should eq 1
        end
      end

      context "unneeded disables" do
        it "reports an issue if such disable exists" do
          rules = [
            Rule::Lint::UnneededDisableDirective.new,
            Rule::Lint::NotNil.new,
          ] of Rule::Base
          source = Source.new <<-CRYSTAL
            a = 1 # ameba:disable Lint/NotNil
            CRYSTAL

          Runner.new(rules, [source], formatter, default_severity).run
          source.should_not be_valid
          source.issues.first.rule.should be_a Rule::Lint::UnneededDisableDirective
        end

        it "does not report if the disabled rule is excluded for the source" do
          path = "source.cr"
          error_rule = ErrorRule.new
          error_rule.excluded = Set{path}
          rules = [error_rule, Rule::Lint::UnneededDisableDirective.new] of Rule::Base
          source = Source.new <<-CRYSTAL, path
            a = 1 # ameba:disable #{ErrorRule.rule_name}
            CRYSTAL

          Runner.new(rules, [source], formatter, default_severity).run
          source.should be_valid
        end

        it "respects Excluded config of UnneededDisableDirective" do
          path = "source.cr"
          udd_rule = Rule::Lint::UnneededDisableDirective.new
          udd_rule.excluded = Set{path}
          rules = [udd_rule] of Rule::Base
          source = Source.new <<-CRYSTAL, path
            a = 1 # ameba:disable LineLength
            CRYSTAL

          Runner.new(rules, [source], formatter, default_severity).run
          source.should be_valid
        end
      end

      it "discards corrections leaving the source unparsable" do
        rules = [BreakingCorrectionRule.new.tap(&.enabled = true)] of Rule::Base
        path = File.tempname("source", ".cr")
        File.write(path, "bar\n")
        source = Source.new("bar\n", path)

        begin
          Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run
          source.code.should eq "bar\n"
          source.lines.should eq ["bar", ""]
          source.ast.should_not be_nil
          File.read(path).should eq "bar\n"
          source.issues.size.should eq 1
          source.issues.first.message.should start_with "bar"
          source.issues.first.message.should contain "invalid syntax"
          source.issues.first.correctable?.should be_false
        ensure
          File.delete(path) rescue nil
        end
      end

      it "keeps earlier corrections if a later one leaves the source unparsable" do
        rules = [BreakingCorrectionRule.new.tap(&.enabled = true)] of Rule::Base
        path = File.tempname("source", ".cr")
        File.write(path, "foo\n")
        source = Source.new("foo\n", path)

        begin
          Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run
          source.code.should eq "bar\n"
          File.read(path).should eq "bar\n"
          source.issues.map(&.message.split.first).should eq ["foo", "bar"]
          source.issues.map(&.correctable?).should eq [true, false]
        ensure
          File.delete(path) rescue nil
        end
      end

      it "keeps other corrections when one of them leaves the source unparsable" do
        [false, true].each do |reverse|
          rules = [
            BreakingCorrectionRule.new.tap(&.enabled = true),
            Rule::Lint::NotNilAfterNoBang.new,
          ] of Rule::Base
          rules.reverse! if reverse
          path = File.tempname("source", ".cr")
          code = "bar\nbaz.match(/x/).not_nil!\n"
          File.write(path, code)
          source = Source.new(code, path)

          begin
            Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run
            source.code.should eq "bar\nbaz.match!(/x/)\n"
            File.read(path).should eq source.code
            source.issues.map(&.correctable?).should eq [false, true]
            source.issues.first.rule.should eq rules.find(&.is_a?(BreakingCorrectionRule))
            source.issues.first.message.should contain "invalid syntax"
            source.issues.last.message.should_not contain "invalid syntax"
          ensure
            File.delete(path) rescue nil
          end
        end
      end

      it "discards corrections leaving the source unparsable only when combined" do
        rules = [IncompatibleCorrectionsRule.new.tap(&.enabled = true)] of Rule::Base
        path = File.tempname("source", ".cr")
        code = "x = 1\n2\n"
        File.write(path, code)
        source = Source.new(code, path)

        begin
          Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run
          source.code.should eq code
          File.read(path).should eq code
          source.issues.map(&.correctable?).should eq [false, false]
          source.issues.each(&.message.should contain "invalid syntax")
        ensure
          File.delete(path) rescue nil
        end
      end

      it "does not annotate issues without a correction when discarding corrections" do
        rules = [IncompatibleCorrectionsRule.new.tap(&.enabled = true), ErrorRule.new] of Rule::Base
        path = File.tempname("source", ".cr")
        code = "x = 1\n2\n"
        File.write(path, code)
        source = Source.new(code, path)

        begin
          Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run
          source.issues.find!(&.rule.is_a?(IncompatibleCorrectionsRule)).message.should contain "invalid syntax"
          source.issues.find!(&.rule.is_a?(ErrorRule)).message.should_not contain "invalid syntax"
        ensure
          File.delete(path) rescue nil
        end
      end

      it "handles rules with incompatible autocorrect" do
        rules = [Rule::Performance::MinMaxAfterMap.new, Rule::Style::VerboseBlock.new]
        source = Source.new <<-CRYSTAL, File.tempname("source", ".cr")
          list.map { |i| i.size }.max
          CRYSTAL

        begin
          Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run
          source.code.should eq "list.max_of(&.size)"
          source.issues.map(&.rule).should eq rules
        ensure
          File.delete(source.path) rescue nil
        end
      end

      it "handles deeply nested conflicting autocorrections in either rule order" do
        [false, true].each do |reverse|
          rules = [
            Rule::Performance::MinMaxAfterMap.new,
            Rule::Style::VerboseBlock.new
              .tap(&.exclude_calls_with_block = false),
          ]
          rules.reverse! if reverse
          source = Source.new <<-CRYSTAL, File.tempname("source", ".cr")
            list.map { |group| group.map { |arr| arr.map(&.size).max }.max }.max
            CRYSTAL

          begin
            Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run
            source.code.should eq "list.max_of(&.max_of(&.max_of(&.size)))"
            File.read(source.path).should eq source.code
          ensure
            File.delete(source.path) rescue nil
          end
        end
      end

      it "preserves semantics of conflicting autocorrections in either rule order" do
        {
          false => "if foo\n  :ok\nelse\n  :nok\nend",
          true  => "if !foo\n  :nok\nelse\n  :ok\nend",
        }.each do |reverse, expected|
          rules = [
            Rule::Style::NegatedConditionsInUnless.new,
            Rule::Style::UnlessElse.new,
          ] of Rule::Base
          rules.reverse! if reverse
          source = Source.new <<-CRYSTAL, File.tempname("source", ".cr")
            unless !foo
              :ok
            else
              :nok
            end
            CRYSTAL

          begin
            Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run
            source.code.should eq expected
          ensure
            File.delete(source.path) rescue nil
          end
        end
      end

      it "handles rules with incompatible, conflicting autocorrect" do
        rules = [
          Rule::Performance::MinMaxAfterMap.new,
          # The default excludes bodies with short blocks, including the nested `max` call.
          Rule::Style::VerboseBlock.new
            .tap(&.exclude_calls_with_block = false),
        ]
        source = Source.new <<-CRYSTAL, File.tempname("source", ".cr")
          list.map { |arr| arr.map(&.size).max }.max
          CRYSTAL

        begin
          Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run
          source.code.should eq "list.max_of(&.max_of(&.size))"
          source.issues.map(&.rule).should eq [rules.first, rules.last, rules.first]
        ensure
          File.delete(source.path) rescue nil
        end
      end
    end

    describe "#explain" do
      output = IO::Memory.new

      before_each do
        output.clear
      end

      it "writes nothing if sources are valid" do
        runner = runner(formatter: formatter).run
        runner.explain(Crystal::Location.new("source.cr", 1, 2), output)
        output.to_s.should be_empty
      end

      it "writes the explanation if sources are not valid and location found" do
        rules = [ErrorRule.new] of Rule::Base
        source = Source.new("a = 1", "source.cr")

        runner = Runner.new(rules, [source], formatter, default_severity).run
        runner.explain(Crystal::Location.new("source.cr", 1, 1), output)
        output.to_s.should_not be_empty
      end

      it "writes nothing if sources are not valid and location is not found" do
        rules = [ErrorRule.new] of Rule::Base
        source = Source.new("a = 1", "source.cr")

        runner = Runner.new(rules, [source], formatter, default_severity).run
        runner.explain(Crystal::Location.new("source.cr", 1, 2), output)
        output.to_s.should be_empty
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
        rules = Rule.rules.map(&.new.as(Rule::Base))
        source = Source.new("WrongConstant = 5")

        Runner.new(rules, [source], formatter, default_severity).run.success?.should be_false
      end

      it "depends on the level of severity" do
        rules = Rule.rules.map(&.new.as(Rule::Base))
        source = Source.new("WrongConstant = 5\n")

        Runner.new(rules, [source], formatter, :error).run.success?.should be_true
        Runner.new(rules, [source], formatter, :warning).run.success?.should be_true
        Runner.new(rules, [source], formatter, :convention).run.success?.should be_false
      end

      it "returns false if issue is disabled" do
        rules = [NamedRule.new] of Rule::Base
        source = Source.new <<-CRYSTAL
          def foo
            bar = 1 # ameba:disable #{NamedRule.name}
          end
          CRYSTAL
        source.add_issue NamedRule.new, location: {2, 1},
          message: "Useless assignment"

        Runner
          .new(rules, [source], formatter, default_severity)
          .run.success?.should be_true
      end
    end

    describe "#run with rules autocorrecting each other" do
      context "with two conflicting rules" do
        context "if there is an offense in an inspected file" do
          it "aborts because of an infinite loop" do
            rules = [AtoB.new, BtoA.new]
            source = Source.new("class A; end", "source.cr")
            message = "Infinite loop in source.cr caused by Ameba/AtoB -> Ameba/BtoA"

            expect_raises(Runner::InfiniteCorrectionLoopError, message) do
              Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run
            end
          end
        end

        context "if there are multiple offenses in an inspected file" do
          it "aborts because of an infinite loop" do
            rules = [AtoB.new, BtoA.new]
            source = Source.new <<-CRYSTAL, "source.cr"
              class A; end
              class A_A; end
              CRYSTAL
            message = "Infinite loop in source.cr caused by Ameba/AtoB -> Ameba/BtoA"

            expect_raises(Runner::InfiniteCorrectionLoopError, message) do
              Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run
            end
          end
        end
      end

      context "with two pairs of conflicting rules" do
        it "aborts because of an infinite loop" do
          rules = [ClassToModule.new, ModuleToClass.new, AtoB.new, BtoA.new]
          source = Source.new("class A_A; end", "source.cr")
          message = "Infinite loop in source.cr caused by Ameba/ClassToModule, Ameba/AtoB -> Ameba/ModuleToClass, Ameba/BtoA"

          expect_raises(Runner::InfiniteCorrectionLoopError, message) do
            Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run
          end
        end
      end

      context "with three rule cycle" do
        it "aborts because of an infinite loop" do
          rules = [AtoB.new, BtoC.new, CtoA.new]
          source = Source.new("class A; end", "source.cr")
          message = "Infinite loop in source.cr caused by Ameba/AtoB -> Ameba/BtoC -> Ameba/CtoA"

          expect_raises(Runner::InfiniteCorrectionLoopError, message) do
            Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run
          end
        end
      end
    end
  end
end
