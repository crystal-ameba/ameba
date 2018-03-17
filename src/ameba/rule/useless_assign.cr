module Ameba::Rule
  # A rule that disallows useless assignments.
  #
  # For example, this is considered invalid:
  #
  # ```
  # def method
  #   var = 1
  #   do_something
  # end
  # ```
  #
  # And has to be written as the following:
  #
  # ```
  # def method
  #   var = 1
  #   do_something(var)
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # UselessAssign:
  #   Enabled: true
  # ```
  #
  struct UselessAssign < Base
    properties do
      description = "Disallows useless variable assignments"
    end

    def test(source)
      AST::ScopeVisitor.new self, source
    end

    def test(source, node : Crystal::Def | Crystal::ProcLiteral, scope : AST::Scope)
      scope.assigns.each do |assign|
        next unless unused_var?(scope, assign)
        var_name = assign.target.as(Crystal::Var).name
        source.error self, assign.location, "Useless assignment to variable `#{var_name}`"
      end
    end

    private def unused_var?(scope, assign)
      return false unless assign.target.is_a?(Crystal::Var)
      return false if scope.parent.try &.references?(assign)
      !scope.references?(assign)
    end
  end
end
