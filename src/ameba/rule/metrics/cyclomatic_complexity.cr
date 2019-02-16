module Ameba::Rule::Metrics
  # A rule that disallows methods with a cyclomatic complexity higher than `MaxComplexity`
  #
  # YAML configuration example:
  #
  # ```
  # Metrics/CyclomaticComplexity:
  #   Enabled: true
  #   MaxComplexity: 10
  # ```
  #
  struct CyclomaticComplexity < Base
    properties do
      enabled false
      description "Disallows methods with a cyclomatic complexity higher than `MaxComplexity`"
      max_complexity 10
    end

    MSG = "Cyclomatic complexity too high [%d/%d]"

    def test(source)
      AST::NodeVisitor.new self, source
    end

    def test(source, node : Crystal::Def)
      complexity = AST::CountingVisitor.new(node).count

      if complexity > max_complexity
        issue_for(node, MSG % [complexity, max_complexity])
      end
    end
  end
end
