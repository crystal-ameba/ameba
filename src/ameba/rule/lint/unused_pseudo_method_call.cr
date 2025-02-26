module Ameba::Rule::Lint
  # A rule that disallows unused pseudo method calls (is_a?, sizeof, etc).
  #
  # For example, these are considered invalid:
  #
  # ```
  # pointerof(foo)
  # sizeof(Bar)
  #
  # def method
  #   !!valid? if guard?
  #   nil
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/UnusedPseudoMethodCall:
  #   Enabled: true
  # ```
  class UnusedPseudoMethodCall < Base
    properties do
      since_version "1.7.0"
      description "Disallows unused pseudo-method calls"
    end

    MSG = "Pseudo-method call is not used"

    def test(source : Source)
      AST::ImplicitReturnVisitor.new(self, source)
    end

    def test(
      source,
      node : Crystal::PointerOf | Crystal::SizeOf | Crystal::InstanceSizeOf |
             Crystal::AlignOf | Crystal::InstanceAlignOf | Crystal::OffsetOf |
             Crystal::IsA | Crystal::NilableCast | Crystal::RespondsTo | Crystal::Not,
      in_macro : Bool,
    )
      issue_for node, MSG
    end
  end
end
