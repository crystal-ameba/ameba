module Ameba::Rule::Lint
  # A rule that disallows top level `protected` method visibility modifier,
  # since it has no effect.
  #
  # For example, this is considered invalid:
  #
  # ```
  # protected def foo
  # end
  # ```
  #
  # And has to be written as follows:
  #
  # ```
  # def foo
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/UselessVisibilityModifier:
  #   Enabled: true
  # ```
  class UselessVisibilityModifier < Base
    properties do
      since_version "1.7.0"
      description "Disallows top level `protected` method visibility modifier"
    end

    MSG = "Useless visibility modifier"

    def test(source)
      AST::ScopeVisitor.new self, source, skip: [
        Crystal::ClassDef,
        Crystal::EnumDef,
        Crystal::ModuleDef,
      ]
    end

    def test(source, node : Crystal::Def, scope : AST::Scope)
      return if node.receiver || node.name == "->"
      return unless node.visibility.protected?

      issue_for node, MSG
    end
  end
end
