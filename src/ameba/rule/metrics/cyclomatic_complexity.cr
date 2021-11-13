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
  class CyclomaticComplexity < Base
    include AST::Util

    properties do
      description "Disallows methods with a cyclomatic complexity higher than `MaxComplexity`"
      max_complexity 10
    end

    MSG = "Cyclomatic complexity too high [%d/%d]"

    def test(source, node : Crystal::Def)
      complexity = AST::CountingVisitor.new(node).count

      if complexity > max_complexity && (location = node.name_location)
        issue_for location, name_end_location(node),
          MSG % {complexity, max_complexity}
      end
    end
  end
end
