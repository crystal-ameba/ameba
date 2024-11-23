module Ameba::Rule::Lint
  class UnusedLiteral < Base
    properties do
      description "Disallows unused literal values"
    end

    MSG = "Literal value is not used"

    def test(source : Source)
      AST::ImplicitReturnVisitor.new(self, source)
    end

    def test(
      source,
      node : Crystal::BoolLiteral | Crystal::CharLiteral | Crystal::HashLiteral |
             Crystal::ProcLiteral | Crystal::ArrayLiteral | Crystal::RangeLiteral |
             Crystal::RegexLiteral | Crystal::TupleLiteral | Crystal::NumberLiteral |
             Crystal::StringLiteral | Crystal::SymbolLiteral |
             Crystal::NamedTupleLiteral,
      last_is_used : Bool
    ) : Bool
      if !last_is_used
        issue_for node, MSG
      end

      true
    end
  end
end
