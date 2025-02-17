module Ameba::Rule::Lint
  # A rule that disallows unused pseudo methods (is_a?, sizeof, etc).
  #
  # For example, these are considered invalid:
  #
  # ```
  # pointerof(1234_f32)
  #
  # method_call.as(Int32)
  #
  # def method
  #   if guard?
  #     !!valid?
  #   end
  #
  #   true
  # end
  # ```
  #
  # And these are considered valid:
  #
  # ```
  # a : pointerof(1234_f32)
  #
  # var = method_call.as(Int32)
  #
  # def method
  #   if guard?
  #     return !!valid?
  #   end
  #
  #   true
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/UnusedPseudoMethod:
  #   Enabled: true
  # ```
  class UnusedPseudoMethod < Base
    properties do
      since_version "1.7.0"
      description "Disallows unused pseudo-methods"
    end

    MSG = "Pseudo-method is not used"

    def test(source : Source)
      AST::ImplicitReturnVisitor.new(self, source)
    end

    def test(
      source,
      node : Crystal::PointerOf | Crystal::SizeOf | Crystal::InstanceSizeOf |
             Crystal::AlignOf | Crystal::InstanceAlignOf | Crystal::OffsetOf |
             Crystal::IsA | Crystal::NilableCast | Crystal::RespondsTo | Crystal::Not,
      node_is_used : Bool,
    )
      issue_for node, MSG unless node_is_used
    end
  end
end
