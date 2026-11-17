module Ameba::AST
  class MacroReferenceFinder < Crystal::Visitor
    property? references = false

    @reference : Regex
    @scanner = MacroCodeScanner.new

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
      !(@references ||= includes_reference?(@scanner.scan(node.value)))
    end

    def visit(node : Crystal::MacroExpression)
      @scanner.after_value! if node.output?

      !(@references ||= includes_reference?(node.exp))
    end

    def visit(node : Crystal::MacroFor)
      !(@references ||= includes_reference?(node.exp))
    end

    def visit(node : Crystal::MacroIf)
      return false if @references ||= includes_reference?(node.cond)

      # Both branches start in the same lexical state
      scanner = @scanner.clone
      node.then.accept(self)

      unless node.else.is_a?(Crystal::Nop)
        @scanner = scanner
        node.else.accept(self)
      end
      false
    end

    def visit(node : Crystal::ASTNode)
      true
    end
  end
end
