require "../../spec_helper"

private def get_sarif_result(sources = [Ameba::Source.new])
  output = IO::Memory.new
  formatter = Ameba::Formatter::SARIFFormatter.new output

  formatter.started sources
  sources.each { |source| formatter.source_finished source }
  formatter.finished sources

  JSON.parse(output.to_s)
end

module Ameba::Formatter
  describe SARIFFormatter do
    context "SARIF structure" do
      result = get_sarif_result

      it "includes correct schema" do
        result["$schema"].should eq "https://www.schemastore.org/schemas/json/sarif-2.1.0-rtm.6.json"
      end

      it "includes correct version" do
        result["version"].should eq "2.1.0"
      end

      it "includes runs array" do
        result["runs"].as_a.should_not be_nil
      end
    end

    context "tool information" do
      result = get_sarif_result

      it "includes tool name" do
        result["runs"][0]["tool"]["driver"]["name"].should eq "ameba"
      end

      it "includes ameba version" do
        result["runs"][0]["tool"]["driver"]["version"].should eq Ameba::VERSION
      end

      it "includes information URI" do
        result["runs"][0]["tool"]["driver"]["informationUri"].should eq "https://crystal-ameba.github.io/"
      end

      it "includes rules array" do
        rules = result["runs"][0]["tool"]["driver"]["rules"].as_a
        rules.should_not be_empty
      end

      it "includes rule descriptors" do
        rule = result["runs"][0]["tool"]["driver"]["rules"][0]
        rule["id"].should_not be_nil
        rule["shortDescription"].should_not be_nil
        rule["fullDescription"].should_not be_nil
        rule["help"].should_not be_nil
        rule["defaultConfiguration"].should_not be_nil
        rule["helpUri"].should_not be_nil
      end

      it "includes rule help with text and markdown" do
        rule = result["runs"][0]["tool"]["driver"]["rules"][0]
        rule["help"]["text"].should_not be_nil
        rule["help"]["markdown"].should_not be_nil
      end

      it "includes rule short description with text and markdown" do
        rule = result["runs"][0]["tool"]["driver"]["rules"][0]
        rule["shortDescription"]["text"].should_not be_nil
        rule["shortDescription"]["markdown"].should_not be_nil
      end

      it "includes rule default configuration" do
        rule = result["runs"][0]["tool"]["driver"]["rules"][0]
        config = rule["defaultConfiguration"]
        config["level"].should_not be_nil
        config["parameters"].should_not be_nil
      end
    end

    context "results" do
      it "doesn't include results when no issues" do
        result = get_sarif_result [Source.new path: "source.cr"]
        result["runs"][0]["results"].as_a.should be_empty
      end

      it "includes issue message" do
        source = Source.new path: "source.cr"
        source.add_issue DummyRule.new, {1, 2}, "Test message"

        result = get_sarif_result [source]
        issue = result["runs"][0]["results"][0]
        issue["message"]["text"].should eq "Test message"
        issue["message"]["markdown"].should eq "Test message"
      end

      it "includes rule id" do
        source = Source.new path: "source.cr"
        source.add_issue DummyRule.new, {1, 2}, "message"

        result = get_sarif_result [source]
        issue = result["runs"][0]["results"][0]
        issue["ruleId"].should eq DummyRule.rule_name
      end

      it "includes rule index" do
        source = Source.new path: "source.cr"
        source.add_issue DummyRule.new, {1, 2}, "message"

        result = get_sarif_result [source]
        issue = result["runs"][0]["results"][0]
        issue["ruleIndex"].as_i64.should be >= 0
      end

      it "includes level from severity" do
        source = Source.new path: "source.cr"
        source.add_issue DummyRule.new, {1, 2}, "message"

        result = get_sarif_result [source]
        issue = result["runs"][0]["results"][0]
        issue["level"].should eq "note"
      end

      it "doesn't include disabled issues" do
        source = Source.new path: "source.cr"
        source.add_issue DummyRule.new, {1, 2}, "message", status: :disabled
        source.add_issue NamedRule.new, {1, 3}, "enabled message"

        result = get_sarif_result [source]
        results = result["runs"][0]["results"].as_a
        results.size.should eq 1
        results[0]["message"]["text"].should eq "enabled message"
      end
    end

    context "locations" do
      it "includes URI" do
        source = Source.new path: "source.cr"
        source.add_issue DummyRule.new, {1, 2}, "message"

        result = get_sarif_result [source]
        location = result["runs"][0]["results"][0]["locations"][0]["physicalLocation"]
        location["artifactLocation"]["uri"].should eq "source.cr"
      end

      it "includes start location" do
        source = Source.new <<-CRYSTAL, "source.cr"
          a = 1
          b = 2
          c = 3
          CRYSTAL
        source.add_issue DummyRule.new, {3, 5}, "message"

        result = get_sarif_result [source]
        region = result["runs"][0]["results"][0]["locations"][0]["physicalLocation"]["region"]
        region["startLine"].should eq 3
        region["startColumn"].should eq 5
      end

      it "includes end location" do
        source = Source.new <<-CRYSTAL
          a = 1
          b = 2
          c = 3
          CRYSTAL
        source.add_issue DummyRule.new,
          Crystal::Location.new("path", 2, 3),
          Crystal::Location.new("path", 3, 4),
          "message"

        result = get_sarif_result [source]
        region = result["runs"][0]["results"][0]["locations"][0]["physicalLocation"]["region"]
        region["startLine"].should eq 2
        region["startColumn"].should eq 3
        region["endLine"].should eq 3
        region["endColumn"].should eq 4
      end
    end

    context "context region" do
      it "includes context region with snippet and surrounding context" do
        source = Source.new <<-CRYSTAL
          class Foo
            def initialize
              @value = 0
            end
            def value
          CRYSTAL
        source.add_issue DummyRule.new, {3, 3}, "message"

        result = get_sarif_result [source]
        context_region = result["runs"][0]["results"][0]["locations"][0]["physicalLocation"]["contextRegion"]
        context_region.should_not be_nil
        # Should include 2 lines before and after (lines 1-5)
        snippet = context_region["snippet"]["text"].as_s
        snippet.should contain "class Foo"
        snippet.should contain "@value = 0"
        snippet.should contain "def value"
      end

      it "includes context region with expanded line coordinates" do
        source = Source.new <<-CRYSTAL
          module App
            class User
              property name : String
              property email : String
              def initialize(@name, @email)
              end
          CRYSTAL
        source.add_issue DummyRule.new,
          Crystal::Location.new("path", 3, 1),
          Crystal::Location.new("path", 4, 5),
          "message"

        result = get_sarif_result [source]
        context_region = result["runs"][0]["results"][0]["locations"][0]["physicalLocation"]["contextRegion"]
        # Context should expand by 2 lines in each direction (clamped to file bounds)
        context_region["startLine"].should eq 1 # max(1, 3-2) = 1
        context_region["endLine"].should eq 6   # min(6, 4+2) = 6
        # No column fields in contextRegion (spans full lines)
        context_region["startColumn"]?.should be_nil
        context_region["endColumn"]?.should be_nil
      end

      it "omits context region when file is too small for expansion" do
        source = Source.new <<-CRYSTAL, "source.cr"
          x = 1
          CRYSTAL
        source.add_issue DummyRule.new, {1, 1}, "message"

        result = get_sarif_result [source]
        physical_location = result["runs"][0]["results"][0]["locations"][0]["physicalLocation"]
        # contextRegion should be omitted when it would be identical to region
        physical_location["contextRegion"]?.should be_nil
      end

      it "sets source language to Crystal by default" do
        source = Source.new <<-CRYSTAL, "source.cr"
          def greet
            puts "Hello"
          end
          greet
          CRYSTAL
        source.add_issue DummyRule.new, {2, 1}, "message"

        result = get_sarif_result [source]
        context_region = result["runs"][0]["results"][0]["locations"][0]["physicalLocation"]["contextRegion"]
        context_region["sourceLanguage"].should eq "Crystal"
      end

      it "sets source language to ECR for ECR files" do
        source = Source.new <<-CRYSTAL, "template.ecr"
          <html>
          <body>
          <p>Hello</p>
          </body>
          CRYSTAL
        source.add_issue DummyRule.new, {2, 1}, "message"

        result = get_sarif_result [source]
        context_region = result["runs"][0]["results"][0]["locations"][0]["physicalLocation"]["contextRegion"]
        context_region["sourceLanguage"].should eq "ECR"
      end

      it "includes multi-line snippets with surrounding context" do
        source = Source.new <<-CRYSTAL
          def calculate
            sum = 0
            sum += 1
          end
          CRYSTAL
        source.add_issue DummyRule.new,
          Crystal::Location.new("path", 2, 1),
          Crystal::Location.new("path", 3, 10),
          "message"

        result = get_sarif_result [source]
        context_region = result["runs"][0]["results"][0]["locations"][0]["physicalLocation"]["contextRegion"]
        # Should include the issue lines plus surrounding context
        snippet = context_region["snippet"]["text"].as_s
        snippet.should contain "def calculate"
        snippet.should contain "sum = 0"
        snippet.should contain "sum += 1"
        snippet.should contain "end"
      end

      it "clamps context to file boundaries at start" do
        source = Source.new <<-CRYSTAL
          a = 1
          b = 2
          c = 3
          d = 4
          CRYSTAL
        source.add_issue DummyRule.new, {1, 1}, "message"

        result = get_sarif_result [source]
        context_region = result["runs"][0]["results"][0]["locations"][0]["physicalLocation"]["contextRegion"]
        # Can only expand downward since we're at line 1
        context_region["startLine"].should eq 1
        context_region["endLine"].should eq 3 # min(4, 1+2) = 3
      end

      it "clamps context to file boundaries at end" do
        source = Source.new <<-CRYSTAL
          a = 1
          b = 2
          c = 3
          d = 4
          CRYSTAL
        source.add_issue DummyRule.new, {4, 1}, "message"

        result = get_sarif_result [source]
        context_region = result["runs"][0]["results"][0]["locations"][0]["physicalLocation"]["contextRegion"]
        # Can only expand upward since we're at the last line
        context_region["startLine"].should eq 2 # max(1, 4-2) = 2
        context_region["endLine"].should eq 4
      end
    end

    context "severity mapping" do
      it "maps error severity to error level" do
        source = Source.new path: "source.cr"
        source.add_issue TestErrorRule.new, {1, 1}, "message"

        result = get_sarif_result [source]
        result["runs"][0]["results"][0]["level"].should eq "error"
      end

      it "maps warning severity to warning level" do
        source = Source.new path: "source.cr"
        source.add_issue TestWarningRule.new, {1, 1}, "message"

        result = get_sarif_result [source]
        result["runs"][0]["results"][0]["level"].should eq "warning"
      end

      it "maps convention severity to note level" do
        source = Source.new path: "source.cr"
        source.add_issue DummyRule.new, {1, 1}, "message"

        result = get_sarif_result [source]
        result["runs"][0]["results"][0]["level"].should eq "note"
      end
    end

    context "multiple sources" do
      it "includes issues from multiple sources" do
        source1 = Source.new path: "source1.cr"
        source1.add_issue DummyRule.new, {1, 1}, "message 1"

        source2 = Source.new path: "source2.cr"
        source2.add_issue NamedRule.new, {2, 2}, "message 2"

        result = get_sarif_result [source1, source2]
        results = result["runs"][0]["results"].as_a
        results.size.should eq 2
      end

      it "formats paths correctly" do
        source = Source.new path: "src/foo/bar.cr"
        source.add_issue DummyRule.new, {1, 1}, "message"

        result = get_sarif_result [source]
        uri = result["runs"][0]["results"][0]["locations"][0]["physicalLocation"]["artifactLocation"]["uri"]
        uri.should eq "src/foo/bar.cr"
      end
    end

    context "invocations" do
      it "includes executionSuccessful true when no syntax errors" do
        source = Source.new path: "source.cr"
        source.add_issue DummyRule.new, {1, 1}, "message"

        result = get_sarif_result [source]
        invocations = result["runs"][0]["invocations"].as_a
        invocations[0]["executionSuccessful"].should be_true
      end

      it "includes executionSuccessful false when syntax errors exist" do
        source = Source.new "def foo", "source.cr"
        source.add_issue Rule::Lint::Syntax.new, {1, 1}, "unexpected token: EOF"

        result = get_sarif_result [source]
        invocations = result["runs"][0]["invocations"].as_a
        invocations[0]["executionSuccessful"].should be_false
      end

      it "includes empty ruleConfigurationOverrides when no rules are overridden" do
        source = Source.new path: "source.cr"
        output = IO::Memory.new
        formatter = Ameba::Formatter::SARIFFormatter.new output

        formatter.rules = [DummyRule.new] of Rule::Base

        formatter.started [source]
        formatter.source_finished source
        formatter.finished [source]

        result = JSON.parse(output.to_s)
        invocations = result["runs"][0]["invocations"].as_a
        invocations[0]["ruleConfigurationOverrides"].as_a.should be_empty
      end

      it "includes invocations when rule is disabled" do
        source = Source.new path: "source.cr"
        output = IO::Memory.new
        formatter = Ameba::Formatter::SARIFFormatter.new output

        rule = DummyRule.new
        rule.enabled = false
        formatter.rules = [rule] of Rule::Base

        formatter.started [source]
        formatter.source_finished source
        formatter.finished [source]

        result = JSON.parse(output.to_s)
        invocations = result["runs"][0]["invocations"].as_a
        invocations.size.should eq 1

        overrides = invocations[0]["ruleConfigurationOverrides"].as_a
        overrides.size.should be >= 1

        override = overrides.find { |override_item| override_item["descriptor"]["id"] == DummyRule.rule_name }
        if config = override
          config["configuration"]["enabled"].should be_false
        end
      end

      it "includes invocations when rule severity is changed" do
        source = Source.new path: "source.cr"
        output = IO::Memory.new
        formatter = Ameba::Formatter::SARIFFormatter.new output

        rule = DummyRule.new
        rule.severity = Severity::Error # Default is Convention
        formatter.rules = [rule] of Rule::Base

        formatter.started [source]
        formatter.source_finished source
        formatter.finished [source]

        result = JSON.parse(output.to_s)
        invocations = result["runs"][0]["invocations"].as_a
        overrides = invocations[0]["ruleConfigurationOverrides"].as_a

        override = overrides.find { |override_item| override_item["descriptor"]["id"] == DummyRule.rule_name }
        if config = override
          config["configuration"]["level"].should eq "error"
        end
      end

      it "includes descriptor index in overrides" do
        source = Source.new path: "source.cr"
        output = IO::Memory.new
        formatter = Ameba::Formatter::SARIFFormatter.new output

        rule = DummyRule.new
        rule.enabled = false
        formatter.rules = [rule] of Rule::Base

        formatter.started [source]
        formatter.source_finished source
        formatter.finished [source]

        result = JSON.parse(output.to_s)
        overrides = result["runs"][0]["invocations"][0]["ruleConfigurationOverrides"].as_a

        override = overrides.find { |override_item| override_item["descriptor"]["id"] == DummyRule.rule_name }
        if config = override
          config["descriptor"]["index"].as_i64.should be >= 0
        end
      end

      it "works without rules being set" do
        source = Source.new path: "source.cr"
        source.add_issue DummyRule.new, {1, 1}, "message"

        result = get_sarif_result [source]
        # Should include invocations with execution status even without rules being set
        invocations = result["runs"][0]["invocations"].as_a
        invocations[0]["executionSuccessful"].should be_true
        invocations[0]["ruleConfigurationOverrides"].as_a.should be_empty
      end
    end
  end
end
