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
        next unless scope.unused_var?(assign)
        var_name = assign.target.as(Crystal::Var).name
        source.error self, assign.location, "Useless assignment to variable `#{var_name}`"
      end
    end
  end
end
