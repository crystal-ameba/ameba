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

    def test(source, node : Crystal::Def, scope : AST::Scope)
      scope.targets.each do |target|
        next unless unused_var?(scope, target)
        var_name = target.as(Crystal::Var).name
        source.error self, target.location, "Useless assignment to variable `#{var_name}`"
      end
    end

    private def unused_var?(scope, target)
      return false unless target.is_a?(Crystal::Var)
      return false if scope.captured_by_block?(target)

      !scope.referenced?(target)
    end
  end
end
