module Ameba::Rule::Lint
  # A rule that disallows unused `self`.
  #
  # For example, this is considered invalid:
  #
  # ```
  # class MyClass
  #   self
  # end
  # ```
  #
  # And these are considered valid:
  #
  # ```
  # class MyClass
  #   def self.hello
  #     puts "Hello, world!"
  #   end
  #
  #   self.hello
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/UnusedSelf:
  #   Enabled: true
  # ```
  class UnusedSelf < Base
    properties do
      since_version "1.7.0"
      description "Disallows unused self"
    end

    MSG = "`self` is not used"

    def test(source : Source)
      AST::ImplicitReturnVisitor.new(self, source)
    end

    def test(source, node : Crystal::Self, node_is_used : Bool)
      issue_for node, MSG unless node_is_used
    end

    def test(source, node : Crystal::Var, node_is_used : Bool)
      return if node_is_used || node.name != "self"

      issue_for node, MSG
    end
  end
end
