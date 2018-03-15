module Ameba::Rule
  struct UselessAssign < Base
    properties do
      description = "Disallows useless variable assignments"
    end

    def test(source)
      AST::ScopeVisitor.new self, source
    end

    def test(source, node, scope : AST::Scope)
      scope.assigns.each do |assign|
        next if scope.used?(assign)
        source.error self, assign.location, "Useless assignment found"
      end
    end
  end
end
