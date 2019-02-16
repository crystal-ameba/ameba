module Ameba::AST
  # AST Visitor that counts occurences of certain keywords
  class CountingVisitor < Crystal::Visitor
    @complexity = 1

    # Creates a new counting visitor
    def initialize(@scope : Crystal::ASTNode)
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode)
      true
    end

    # Returns the number of keywords that were found in the node
    def count
      @scope.accept(self)
      @complexity
    end

    # Uses the same logic than rubocop. See
    # https://github.com/rubocop-hq/rubocop/blob/master/lib/rubocop/cop/metrics/cyclomatic_complexity.rb#L21
    # Except "for", because crystal doesn't have a "for" loop.
    {% for node in %i(if while until rescue when or and) %}
      # :nodoc:
      def visit(node : Crystal::{{ node.id.capitalize }})
        @complexity += 1
      end
    {% end %}
  end
end
