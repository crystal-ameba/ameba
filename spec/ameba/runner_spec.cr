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

      it "reports an infinite loop" do
        rules = [AtoAA.new] of Rule::Base
        source = Source.new("class A; end", "source.cr")
        message = "Infinite loop in source.cr caused by Ameba/AtoAA"

        Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run

        source.issues.find!(&.crashed?).message.should eq message
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

      context "#crashed?" do
        it "is false if nothing raised" do
          source = Source.new(path: "source.cr")

          Runner.new([ErrorRule.new] of Rule::Base, [source], formatter, default_severity).run
            .crashed?.should be_false
        end

        it "is true if a rule raised" do
          rule = RaiseRule.new
          rule.should_raise = true
          source = Source.new(path: "source.cr")

          Runner.new([rule] of Rule::Base, [source], formatter, default_severity).run
            .crashed?.should be_true
        end

        it "is true if any of the sources has a correction which raised" do
          rules = [RaisingCorrectionRule.new.tap(&.enabled = true)] of Rule::Base
          path = File.tempname("source", ".cr")
          File.write(path, "foo\n")
          sources = [Source.new("bar\n", "other.cr"), Source.new("foo\n", path)]

          begin
            Runner.new(rules, sources, formatter, default_severity, autocorrect: true).run
              .crashed?.should be_true
          ensure
            File.delete(path) rescue nil
          end
        end

        it "is false if a correction would raise but autocorrect is off" do
          rules = [RaisingCorrectionRule.new.tap(&.enabled = true)] of Rule::Base
          source = Source.new("foo\n", "source.cr")

          Runner.new(rules, [source], formatter, default_severity).run
            .crashed?.should be_false
        end
      end

      context "exception in rule" do
        it "reports an exception raised while running a rule" do
          rule = RaiseRule.new
          rule.should_raise = true
          rules = [rule] of Rule::Base
          source = Source.new(path: "source.cr")

          runner = Runner.new(rules, [source], formatter, default_severity).run

          runner.success?.should be_false
          source.issues.size.should eq 1
          source.issues.first.rule.should eq rule
          source.issues.first.message.should contain "something went wrong"
          source.issues.first.location.try(&.line_number).should eq 1
        end

        it "can't be disabled by an inline directive" do
          rule = RaiseRule.new
          rule.should_raise = true
          source = Source.new("a = 1 # ameba:disable #{RaiseRule.rule_name}\n", "source.cr")

          Runner.new([rule] of Rule::Base, [source], formatter, default_severity).run

          source.issues.first.enabled?.should be_true
        end

        it "keeps running the other rules" do
          rule = RaiseRule.new
          rule.should_raise = true
          rules = [rule, ErrorRule.new] of Rule::Base
          source = Source.new(path: "source.cr")

          Runner.new(rules, [source], formatter, default_severity).run

          source.issues.map(&.rule.class).should contain ErrorRule
          source.issues.map(&.rule.class).should contain RaiseRule
        end

        it "keeps inspecting and correcting the other sources" do
          rule = RaiseRule.new
          rule.should_raise = true
          rules = [rule, Rule::Lint::NotNilAfterNoBang.new] of Rule::Base
          paths = {File.tempname("source", ".cr"), File.tempname("source", ".cr")}
          code = "foo.match(/x/).not_nil!\n"
          paths.each { |path| File.write(path, code) }
          sources = paths.map { |path| Source.new(code, path) }.to_a

          begin
            runner = Runner.new(rules, sources, formatter, default_severity, autocorrect: true).run

            runner.success?.should be_false
            paths.each { |path| File.read(path).should eq "foo.match!(/x/)\n" }
          ensure
            paths.each { |path| File.delete(path) rescue nil }
          end
        end
      end

      context "exception in correction" do
        it "reports the issue as uncorrected, keeping the other corrections" do
          rules = [RaisingCorrectionRule.new.tap(&.enabled = true), Rule::Lint::NotNilAfterNoBang.new] of Rule::Base
          path = File.tempname("source", ".cr")
          code = "foo\nbar.match(/x/).not_nil!\n"
          File.write(path, code)
          source = Source.new(code, path)

          begin
            runner = Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run

            File.read(path).should eq "foo\nbar.match!(/x/)\n"
            runner.success?.should be_false

            issue = source.issues.find!(&.rule.is_a?(RaisingCorrectionRule))
            issue.correctable?.should be_false
            issue.corrected?.should be_false
            issue.message.should contain "correction went wrong"
          ensure
            File.delete(path) rescue nil
          end
        end

        it "keeps inspecting and correcting the other sources" do
          rules = [RaisingCorrectionRule.new.tap(&.enabled = true), Rule::Lint::NotNilAfterNoBang.new] of Rule::Base
          raising_path, other_path = File.tempname("source", ".cr"), File.tempname("source", ".cr")
          raising_code, other_code = "foo\n", "bar.match(/x/).not_nil!\n"
          File.write(raising_path, raising_code)
          File.write(other_path, other_code)
          sources = [Source.new(raising_code, raising_path), Source.new(other_code, other_path)]

          begin
            Runner.new(rules, sources, formatter, default_severity, autocorrect: true).run

            File.read(raising_path).should eq raising_code
            File.read(other_path).should eq "bar.match!(/x/)\n"
          ensure
            File.delete(raising_path) rescue nil
            File.delete(other_path) rescue nil
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

      it "handles `Style/RedundantReturn` conflicting over `return(nil)` in either rule order" do
        {
          false => "def foo\n  return\nend\n",
          true  => "def foo\n  nil\nend\n",
        }.each do |reverse, expected|
          rules = [
            Rule::Style::RedundantNilInControlExpression.new,
            Rule::Style::RedundantReturn.new,
          ] of Rule::Base
          rules.reverse! if reverse
          path = File.tempname("source", ".cr")
          code = "def foo\n  return(nil)\nend\n"
          File.write(path, code)
          source = Source.new(code, path)

          begin
            Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run
            source.code.should eq expected
            File.read(path).should eq expected
          ensure
            File.delete(path) rescue nil
          end
        end
      end

      it "succeeds if every issue got corrected" do
        rules = [Rule::Lint::NotNilAfterNoBang.new] of Rule::Base
        path = File.tempname("source", ".cr")
        code = "foo.match(/x/).not_nil!\n"
        File.write(path, code)
        source = Source.new(code, path)

        begin
          runner = Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run
          source.issues.size.should eq 1
          runner.success?.should be_true
        ensure
          File.delete(path) rescue nil
        end
      end

      it "fails if any issue is left uncorrected" do
        rules = [Rule::Lint::NotNilAfterNoBang.new, ErrorRule.new] of Rule::Base
        path = File.tempname("source", ".cr")
        code = "foo.match(/x/).not_nil!\n"
        File.write(path, code)
        source = Source.new(code, path)

        begin
          Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run.success?.should be_false
        ensure
          File.delete(path) rescue nil
        end
      end

      it "fails if a correction left an issue behind" do
        rules = [UselessCorrectionRule.new.tap(&.enabled = true)] of Rule::Base
        path = File.tempname("source", ".cr")
        File.write(path, "foo\n")
        source = Source.new("foo\n", path)

        begin
          Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run.success?.should be_false
        ensure
          File.delete(path) rescue nil
        end
      end

      it "leaves nothing to correct on the source afterwards" do
        rules = [Rule::Lint::NotNilAfterNoBang.new] of Rule::Base
        path = File.tempname("source", ".cr")
        code = "aaa.match(/x/).not_nil!\nbbb.match(/x/).not_nil!\n"
        File.write(path, code)
        source = Source.new(code, path)

        begin
          Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run

          corrected_code = source.code
          source.correct!.should be_nil
          source.code.should eq corrected_code
        ensure
          File.delete(path) rescue nil
        end
      end

      it "marks only the issues which got corrected" do
        rules = [BreakingCorrectionRule.new.tap(&.enabled = true)] of Rule::Base
        path = File.tempname("source", ".cr")
        File.write(path, "foo\n")
        source = Source.new("foo\n", path)

        begin
          Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run
          source.issues.map(&.corrected?).should eq [true, false]
        ensure
          File.delete(path) rescue nil
        end
      end

      it "doesn't mark issues whose correction doesn't change anything" do
        rules = [UselessCorrectionRule.new.tap(&.enabled = true)] of Rule::Base
        path = File.tempname("source", ".cr")
        File.write(path, "foo\n")
        source = Source.new("foo\n", path)

        begin
          Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run
          source.issues.map(&.corrected?).should eq [false]
          source.issues.map(&.correctable?).should eq [true]
        ensure
          File.delete(path) rescue nil
        end
      end

      it "doesn't mark issues without autocorrect" do
        rules = [BreakingCorrectionRule.new.tap(&.enabled = true)] of Rule::Base
        source = Source.new("foo\n", "source.cr")

        Runner.new(rules, [source], formatter, default_severity).run

        source.issues.map(&.corrected?).should eq [false]
        source.issues.map(&.correctable?).should eq [true]
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

    describe "#run with invalid UTF-8" do
      it "reports it as a syntax issue, without aborting the run" do
        path = File.tempname("source", ".cr")
        code = "foo.match(/x/).not_nil!\n"

        File.write(path, code)

        sources = [
          Source.new("# text \xFF\n", "invalid.cr"),
          Source.new(code, path),
        ]
        rules = [Rule::Lint::NotNilAfterNoBang.new] of Rule::Base

        begin
          runner = Runner.new(rules, sources, formatter, default_severity, autocorrect: true).run
          runner.success?.should be_false
          runner.crashed?.should be_false

          sources.first.issues.first.syntax?
            .should be_true

          File.read(path).should eq "foo.match!(/x/)\n"
        ensure
          File.delete(path) rescue nil
        end
      end
    end

    describe "#run when the corrected code can't be written" do
      # A file within a missing directory can't be written on any platform
      unwritable_path = Path[Dir.tempdir, "ameba-missing-#{Process.pid}", "source.cr"]
      code = "foo.match(/x/).not_nil!\n"
      rules = [Rule::Lint::NotNilAfterNoBang.new] of Rule::Base

      it "reports it as a crash, failing the run" do
        source = Source.new(code, unwritable_path)

        runner = Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run

        runner.success?.should be_false
        runner.crashed?.should be_true

        issue = source.issues.find!(&.crashed?)
        issue.message.should contain "Could not write the corrected code"
        issue.message.should contain unwritable_path.basename
      end

      it "doesn't report the issues as corrected" do
        source = Source.new(code, unwritable_path)

        Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run

        issue = source.issues.reject(&.crashed?).first
        issue.corrected?.should be_false
        issue.correctable?.should be_true
        source.issues.size.should eq 2
      end

      it "goes back to the code on disk" do
        source = Source.new(code, unwritable_path)

        Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run

        source.code.should eq code
      end

      it "keeps correcting the other sources" do
        path = File.tempname("source", ".cr")
        File.write(path, code)
        sources = [Source.new(code, unwritable_path), Source.new(code, path)]

        begin
          Runner.new(rules, sources, formatter, default_severity, autocorrect: true).run

          File.read(path).should eq "foo.match!(/x/)\n"
        ensure
          File.delete(path) rescue nil
        end
      end
    end

    describe "#run with a source which can't be read" do
      it "reports it as a crash, without aborting the run" do
        path = File.tempname("source", ".cr")
        code = "foo.match(/x/).not_nil!\n"
        File.write(path, code)
        missing_path = Path[Dir.tempdir, "ameba-missing-#{Process.pid}", "source.cr"]
        sources = [Source.from_file(missing_path), Source.new(code, path)]
        rules = [Rule::Lint::NotNilAfterNoBang.new] of Rule::Base

        begin
          runner = Runner.new(rules, sources, formatter, default_severity, autocorrect: true).run

          runner.crashed?.should be_true
          sources.first.issues.map(&.message).first.should contain "Could not read"
          File.read(path).should eq "foo.match!(/x/)\n"
        ensure
          File.delete(path) rescue nil
        end
      end
    end

    describe "#run with an unexpected failure" do
      it "processes the other sources before raising it" do
        path = File.tempname("source", ".cr")
        code = "foo.match(/x/).not_nil!\n"
        File.write(path, code)
        sources = [Source.new("a = 1\n", "/failing.cr"), Source.new(code, path)]
        rules = [Rule::Lint::NotNilAfterNoBang.new] of Rule::Base

        begin
          expect_raises(Exception, "formatter went wrong") do
            Runner.new(rules, sources, RaisingFormatter.new.tap(&.failing_path = "/failing.cr"), default_severity, autocorrect: true).run
          end

          File.read(path).should eq "foo.match!(/x/)\n"
        ensure
          File.delete(path) rescue nil
        end
      end
    end

    describe "#run with an infinite correction loop" do
      rules = [AtoB.new, BtoA.new] of Rule::Base

      it "doesn't touch the file" do
        path = File.tempname("source", ".cr")
        code = "class A; end\n"
        File.write(path, code)
        source = Source.new(code, path)

        begin
          Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run

          File.read(path).should eq code
          source.code.should eq code
        ensure
          File.delete(path) rescue nil
        end
      end

      it "reports the issues of the original code as uncorrected" do
        source = Source.new("class A; end\n", "source.cr")

        Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run

        issue = source.issues.find!(&.message.== "A to B")
        issue.corrected?.should be_false
        issue.correctable?.should be_true
        source.issues.map(&.message).should_not contain "B to A"
      end

      it "reports the loop only once, on the first line" do
        source = Source.new("\n\nclass A; end\n", "source.cr")

        Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run

        crashed = source.issues.select(&.crashed?)
        crashed.size.should eq 1
        crashed.first.location.try(&.line_number).should eq 1
        crashed.first.rule.should be_a Rule::Base
      end

      it "fails the run" do
        source = Source.new("class A; end\n", "source.cr")

        runner = Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run

        runner.success?.should be_false
        runner.crashed?.should be_true
      end

      it "keeps inspecting and correcting the other sources" do
        looping_path, other_path = File.tempname("source", ".cr"), File.tempname("source", ".cr")
        looping_code, other_code = "class A; end\n", "foo.match(/x/).not_nil!\n"
        File.write(looping_path, looping_code)
        File.write(other_path, other_code)
        sources = [Source.new(looping_code, looping_path), Source.new(other_code, other_path)]
        all_rules = rules + [Rule::Lint::NotNilAfterNoBang.new] of Rule::Base

        begin
          Runner.new(all_rules, sources, formatter, default_severity, autocorrect: true).run

          File.read(looping_path).should eq looping_code
          File.read(other_path).should eq "foo.match!(/x/)\n"
        ensure
          File.delete(looping_path) rescue nil
          File.delete(other_path) rescue nil
        end
      end

      it "drops corrections made before getting stuck, along with their issues" do
        rules_with_fix = rules + [Rule::Lint::NotNilAfterNoBang.new] of Rule::Base
        code = "class A; end\nfoo.match(/x/).not_nil!\n"
        source = Source.new(code, "source.cr")

        Runner.new(rules_with_fix, [source], formatter, default_severity, autocorrect: true).run

        source.code.should eq code
        source.issues.none?(&.corrected?).should be_true
      end

      it "doesn't mark anything as crashed for a clean run" do
        source = Source.new("class C; end\n", "source.cr")

        Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run.crashed?.should be_false
      end
    end

    describe "#run with rules autocorrecting each other" do
      context "with two conflicting rules" do
        context "if there is an offense in an inspected file" do
          it "reports an infinite loop" do
            rules = [AtoB.new, BtoA.new]
            source = Source.new("class A; end", "source.cr")
            message = "Infinite loop in source.cr caused by Ameba/AtoB -> Ameba/BtoA"

            Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run

            source.issues.find!(&.crashed?).message.should eq message
          end
        end

        context "if there are multiple offenses in an inspected file" do
          it "reports an infinite loop" do
            rules = [AtoB.new, BtoA.new]
            source = Source.new <<-CRYSTAL, "source.cr"
              class A; end
              class A_A; end
              CRYSTAL
            message = "Infinite loop in source.cr caused by Ameba/AtoB -> Ameba/BtoA"

            Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run

            source.issues.find!(&.crashed?).message.should eq message
          end
        end
      end

      context "with two pairs of conflicting rules" do
        it "reports an infinite loop" do
          rules = [ClassToModule.new, ModuleToClass.new, AtoB.new, BtoA.new]
          source = Source.new("class A_A; end", "source.cr")
          message = "Infinite loop in source.cr caused by Ameba/ClassToModule, Ameba/AtoB -> Ameba/ModuleToClass, Ameba/BtoA"

          Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run

          source.issues.find!(&.crashed?).message.should eq message
        end
      end

      context "with three rule cycle" do
        it "reports an infinite loop" do
          rules = [AtoB.new, BtoC.new, CtoA.new]
          source = Source.new("class A; end", "source.cr")
          message = "Infinite loop in source.cr caused by Ameba/AtoB -> Ameba/BtoC -> Ameba/CtoA"

          Runner.new(rules, [source], formatter, default_severity, autocorrect: true).run

          source.issues.find!(&.crashed?).message.should eq message
        end
      end
    end
  end
end
