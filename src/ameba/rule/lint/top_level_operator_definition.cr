module Ameba::Rule::Lint
  # A rule that disallows top level operator method definitions, since these cannot be called.
  #
  # For example, this is considered invalid:
  #
  # ```
  # def +(other)
  # end
  # ```
  #
  # And has to be written within a class, struct, or module:
  #
  # ```
  # class Foo
  #   def +(other)
  #   end
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/TopLevelOperatorDefinition:
  #   Enabled: true
  # ```
  class TopLevelOperatorDefinition < Base
    properties do
      since_version "1.7.0"
      description "Disallows top level operator method definitions"
    end

    MSG = "Top level operator method definitions cannot be called"

    def test(source)
      AST::NodeVisitor.new self, source, skip: [
        Crystal::ClassDef,
        Crystal::EnumDef,
        Crystal::ModuleDef,
      ]
    end

    def test(source, node : Crystal::Def)
      return if node.receiver || node.name == "->"
      return if node.name.chars.any?(&.alphanumeric?)

      issue_for node, MSG
    end
  end
end
