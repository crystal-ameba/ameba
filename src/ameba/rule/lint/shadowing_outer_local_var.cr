module Ameba::Rule::Lint
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
  # Lint/ShadowingOuterLocalVar:
  #   Enabled: true
  # ```
  class ShadowingOuterLocalVar < Base
    properties do
      description "Disallows the usage of the same name as outer local variables " \
                  "for block or proc arguments"
    end

    MSG = "Shadowing outer local variable `%s`"

    def test(source)
      AST::ScopeVisitor.new self, source, skip: [
        Crystal::Macro,
        Crystal::MacroFor,
      ]
    end

    def test(source, node : Crystal::ProcLiteral | Crystal::Block, scope : AST::Scope)
      find_shadowing source, scope
    end

    private def find_shadowing(source, scope)
      return unless outer_scope = scope.outer_scope

      each_argument_node(scope) do |arg|
        # TODO: handle unpacked variables from `Block#unpacks`
        next unless name = arg.name.presence

        variable = outer_scope.find_variable(name)

        next if variable.nil? || !variable.declared_before?(arg)
        next if outer_scope.assigns_ivar?(name)
        next if outer_scope.assigns_type_dec?(name)

        issue_for arg.node, MSG % name
      end
    end

    private def each_argument_node(scope, &)
      scope.arguments.each do |arg|
        yield arg unless arg.ignored?
      end
    end
  end
end
