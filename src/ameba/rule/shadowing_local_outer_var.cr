module Ameba::Rule
  # A rule that disallows the usage of the same name as outer local variables
  # for block or proc arguments.
  #
  # For example, this is considered incorrect:
  #
  # ```
  # def some_method
  #   foo = 1
  #
  #   3.times do |foo| # shadowing outer `foo`
  #   end
  # end
  # ```
  #
  # and should be written as:
  #
  # ```
  # def some_method
  #   foo = 1
  #
  #   3.times do |bar|
  #   end
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # ShadowingOuterLocalVar:
  #   Enabled: true
  # ```
  #
  struct ShadowingOuterLocalVar < Base
    properties do
      description "Disallows the usage of the same name as outer local variables" \
                  " for block or proc arguments."
    end

    MSG = "Shadowing outer local variable `%s`"

    def test(source)
      AST::ScopeVisitor.new self, source
    end

    def test(source, node : Crystal::ProcLiteral, scope : AST::Scope)
      find_shadowing source, scope
    end

    def test(source, node : Crystal::Block, scope : AST::Scope)
      find_shadowing source, scope
    end

    private def find_shadowing(source, scope)
      scope.arguments.each do |arg|
        if scope.outer_scope.try &.find_variable(arg.name)
          issue_for arg, MSG % arg.name
        end
      end
    end
  end
end
