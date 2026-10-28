module Ameba::AST
  class MacroReferenceFinder < Crystal::Visitor
    property? references = false

    @reference : Regex

    def initialize(node, reference : String)
      # Matches *reference* as a whole identifier, so that i.e. `b` isn't
      # found within `blk`, `@b`, or `b?`, but still within `b.foo` or `b != c`
      @reference = /(?<![\p{L}\p{N}_@$])#{Regex.escape(reference)}(?![\p{L}\p{N}_?]|!(?![=~]))/
      node.accept(self)
    end

    @[AlwaysInline]
    private def includes_reference?(val)
      val.to_s.matches?(@reference)
    end

    def visit(node : Crystal::MacroLiteral)
      !(@references ||= includes_reference?(node.value))
    end

    def visit(node : Crystal::MacroExpression)
      !(@references ||= includes_reference?(node.exp))
    end

    def visit(node : Crystal::MacroFor)
      !(@references ||= includes_reference?(node.exp) ||
                        includes_reference?(node.body))
    end

    def visit(node : Crystal::MacroIf)
      !(@references ||= includes_reference?(node.cond) ||
                        includes_reference?(node.then) ||
                        includes_reference?(node.else))
    end

    def visit(node : Crystal::ASTNode)
      true
    end
  end
end
