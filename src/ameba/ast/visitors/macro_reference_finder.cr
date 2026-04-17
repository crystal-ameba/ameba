module Ameba::AST
  class MacroReferenceFinder < Crystal::Visitor
    property? references = false

    def initialize(node, @reference : String)
      node.accept self
    end

    @[AlwaysInline]
    private def includes_reference?(val)
      val.to_s.includes?(@reference)
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
