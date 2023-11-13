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
    properties do
      description "Disallows methods with a cyclomatic complexity higher than `MaxComplexity`"
      max_complexity 10
    end

    MSG = "Cyclomatic complexity too high [%d/%d]"

    def test(source, node : Crystal::Def)
      complexity = AST::CountingVisitor.new(node).count
      return unless complexity > max_complexity

      issue_for node, MSG % {complexity, max_complexity}, prefer_name_location: true
    end
  end
end
