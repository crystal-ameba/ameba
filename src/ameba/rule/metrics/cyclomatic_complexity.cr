module Ameba::Rule::Metrics
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
