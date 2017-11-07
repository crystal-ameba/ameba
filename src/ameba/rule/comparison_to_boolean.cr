module Ameba::Rule
  # A rule that disallows comparison to booleans.
  #
  # For example, these are considered invalid:
  #
  # ```
  # foo == true
  # bar != false
  # false === baz
  # ```
  # This is because these expressions evaluate to `true` or `false`, so you
  # could get the same result by using either the variable directly,
  # or negating the variable.
  #
  struct ComparisonToBoolean < Base
    def test(source)
      AST::Visitor.new self, source
    end

    def test(source, node : Crystal::Call)
      comparison? = %w(== != ===).includes?(node.name)
      to_boolean? = node.args.first?.try &.is_a?(Crystal::BoolLiteral) ||
                    node.obj.is_a?(Crystal::BoolLiteral)

      return unless comparison? && to_boolean?

      source.error self, node.location, "Comparison to a boolean is pointless"
    end
  end
end
