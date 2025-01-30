module Ameba::AST
  # AST Visitor that counts occurrences of certain keywords
  class CountingVisitor < Crystal::Visitor
    DEFAULT_COMPLEXITY = 1

    # Returns the number of keywords that were found in the node
    getter count = DEFAULT_COMPLEXITY

    # Returns `true` if the node is within a macro condition
    getter? macro_condition = false

    # Creates a new counting visitor
    def initialize(node : Crystal::ASTNode)
      node.accept self
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode)
      true
    end

    # Uses the same logic than rubocop. See
    # https://github.com/rubocop-hq/rubocop/blob/master/lib/rubocop/cop/metrics/cyclomatic_complexity.rb#L21
    # Except "for", because crystal doesn't have a "for" loop.
    {% for node in %i[if while until rescue or and] %}
      # :nodoc:
      def visit(node : Crystal::{{ node.id.capitalize }})
        @count += 1 unless macro_condition?
      end
    {% end %}

    # :nodoc:
    def visit(node : Crystal::Case)
      return true if macro_condition?

      # Count the complexity of an exhaustive `Case` as 1
      # Otherwise count the number of `When`s
      @count += node.exhaustive? ? 1 : node.whens.size

      true
    end

    def visit(node : Crystal::MacroIf | Crystal::MacroFor)
      @macro_condition = true
      @count = DEFAULT_COMPLEXITY

      false
    end
  end
end
