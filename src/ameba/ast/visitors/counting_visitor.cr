module Ameba::AST
  class CountingVisitor < Crystal::Visitor
    @complexity = 1

    def initialize(@scope : Crystal::ASTNode)
    end

    def visit(node : Crystal::ASTNode)
      true
    end

    def count
      @scope.accept(self)
      @complexity
    end

    {% for node in %i(if while until for rescue when or and) %}
      def visit(node : Crystal::{{ node.id.capitalize }})
        @complexity += 1
      end
    {% end %}
  end
end
