module Ameba::Rule::Metric
  struct CyclomaticComplexity < Base
    def test(source)
      AST::NodeVisitor.new self, source
    end

    def test(source, node : Crystal::Def)
      complexity = CountingVisitor.new(node).count
      issue_for node, "Cyclomatic complexity too high" if complexity > 5
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
