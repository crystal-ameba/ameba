module Ameba::Rule::Lint
  # A rule that reports usage of `initialize` method definition with a `self` receiver.
  # Such definitions are almost always a typo.
  #
  # For example, this is considered invalid:
  #
  # ```
  # class Foo
  #   def self.initialize
  #   end
  # end
  # ```
  #
  # And should be written as:
  #
  # ```
  # class Foo
  #   def initialize
  #   end
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/SelfInitializeDefinition:
  #   Enabled: true
  # ```
  class SelfInitializeDefinition < Base
    properties do
      since_version "1.7.0"
      description "Reports `initialize` method definitions with a `self` receiver"
    end

    MSG = "`initialize` method definition should not have a receiver"

    def test(source : Source)
      AST::NodeVisitor.new self, source, skip: [
        Crystal::EnumDef,
        Crystal::ModuleDef,
      ]
    end

    def test(source, node : Crystal::Def)
      return unless node.name == "initialize"
      return unless (receiver = node.receiver).is_a?(Crystal::Var)
      return unless receiver.name == "self"

      if (location = receiver.location) && (end_location = receiver.end_location)
        issue_for node, MSG do |corrector|
          corrector.remove(location, end_location.adjust(column_number: 1))
        end
      else
        issue_for node, MSG
      end
    end
  end
end
