module Ameba::AST
  # AST Visitor that counts occurrences of certain keywords
  class CountingVisitor < Crystal::Visitor
    DEFAULT_COMPLEXITY = 1

    getter? macro_condition = false

    # Creates a new counting visitor
    def initialize(@scope : Crystal::ASTNode)
      @complexity = DEFAULT_COMPLEXITY
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
    {% for node in %i[if while until rescue or and] %}
      # :nodoc:
      def visit(node : Crystal::{{ node.id.capitalize }})
        @complexity += 1 unless macro_condition?
      end
    {% end %}

    # :nodoc:
    def visit(node : Crystal::Case)
      return true if macro_condition?

      # Count the complexity of an exhaustive `Case` as 1
      # Otherwise count the number of `When`s
      @complexity += node.exhaustive? ? 1 : node.whens.size

      true
    end

    def visit(node : Crystal::MacroIf | Crystal::MacroFor)
      @macro_condition = true
      @complexity = DEFAULT_COMPLEXITY

      false
    end
  end
end
