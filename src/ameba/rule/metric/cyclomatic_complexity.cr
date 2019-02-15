module Ameba::Rule::Metric
  struct CyclomaticComplexity < Base

    properties do
      enabled false
      description "Disallows method with a cyclomatic complexity higher than `MaxComplexity`"
      max_complexity 10
    end

    MSG = "Cyclomatic complexity too high [%d/%d]"
    def test(source)
      AST::NodeVisitor.new self, source
    end

    def test(source, node : Crystal::Def)
      complexity = CountingVisitor.new(node).count
      if complexity > max_complexity
        issue_for(node, MSG % [complexity, max_complexity])
      end
    end

    private class CountingVisitor < Crystal::Visitor
      @complexity = 1

      def initialize(@scope : Crystal::ASTNode)
      end

      def count
        @scope.accept(self)
        @complexity
      end

      def visit(node : Crystal::Or)
        @complexity += 1
      end

      def visit(node : Crystal::And)
        @complexity += 1
      end

      def visit(node : Crystal::While)
        @complexity += 1
      end

      def visit(node : Crystal::If)
        @complexity += 1
      end

      def visit(node : Crystal::ASTNode)
        true
      end
    end
  end
end
