module Ameba::Rule::Metric
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

      # Uses the same logic than rubocop. See
      # https://github.com/rubocop-hq/rubocop/blob/master/lib/rubocop/cop/metrics/cyclomatic_complexity.rb#L21
      {% for node in %i(if while until for rescue when or and) %}
        def visit(node : Crystal::{{ node.id.capitalize }})
          @complexity += 1
        end
      {% end %}

      def visit(node : Crystal::ASTNode)
        true
      end
    end
  end
end
