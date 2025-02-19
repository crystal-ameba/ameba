module Ameba::Rule::Lint
  # A rule that disallows useless method definitions.
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
  # Lint/UselessDef:
  #   Enabled: true
  # ```
  class UselessDef < Base
    properties do
      since_version "1.7.0"
      description "Disallows useless method definitions"
    end

    MSG = "Useless method definition"

    def test(source)
      AST::NodeVisitor.new self, source, skip: [
        Crystal::ClassDef,
        Crystal::EnumDef,
        Crystal::ModuleDef,
      ]
    end

    def test(source, node : Crystal::Def)
      return if node.receiver || node.name.chars.any?(&.alphanumeric?)

      issue_for node, MSG
    end
  end
end
