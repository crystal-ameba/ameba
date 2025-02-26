module Ameba::Rule::Lint
  # A rule that disallows unused accesses of `self`.
  #
  # For example, this is considered invalid:
  #
  # ```
  # class MyClass
  #   self
  #
  #   def self.foo
  #     self
  #     puts "Hello, world!"
  #   end
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/UnusedSelfAccess:
  #   Enabled: true
  # ```
  class UnusedSelfAccess < Base
    properties do
      since_version "1.7.0"
      description "Disallows unused self"
    end

    MSG = "`self` is not used"

    def test(source : Source)
      AST::ImplicitReturnVisitor.new(self, source)
    end

    def test(source, node : Crystal::Self, in_macro : Bool)
      issue_for node, MSG
    end

    def test(source, node : Crystal::Var, in_macro : Bool)
      issue_for node, MSG if node.name == "self"
    end
  end
end
