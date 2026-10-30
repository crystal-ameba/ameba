module Ameba::AST
  # AST Visitor that finds `break` nodes leaving the loop which body is visited,
  # skipping the ones consumed by the nested loops, blocks and procs.
  class LoopBreakVisitor < Crystal::Visitor
    # Returns `true` if a `break` leaving the loop was found
    getter? found = false

    # Creates a new visitor of the loop *body*
    def initialize(body : Crystal::ASTNode)
      body.accept(self)
    end

    # :nodoc:
    #
    # NOTE: `break` might be hidden within the (unparsed) macro code
    def visit(node : Crystal::Break | Crystal::MacroIf | Crystal::MacroFor | Crystal::MacroExpression | Crystal::MacroLiteral | Crystal::MacroVerbatim)
      @found = true
      false
    end

    # :nodoc:
    def visit(node : Crystal::While | Crystal::Until | Crystal::Block | Crystal::ProcLiteral | Crystal::Def)
      false
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode)
      !@found
    end
  end
end
