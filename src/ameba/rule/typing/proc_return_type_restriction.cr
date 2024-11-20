module Ameba::Rule::Typing
  class ProcReturnTypeRestriction < Base
    properties do
      description "Disallows proc literals without return type restrictions"
    end

    MSG = "Proc literals require a return type"

    def test(source, node : Crystal::ProcLiteral)
      return if node.def.return_type

      issue_for node, MSG
    end
  end
end
