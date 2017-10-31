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
# could get the same result by using either the variable directly, or negating
# the variable.

Ameba.rule ComparisonToBoolean do |source|
  ComparisonToBooleanVisitor.new self, source
end

Ameba.visitor ComparisonToBoolean, Crystal::Call do |node|
  if %w(== != ===).includes?(node.name) && (
       node.args.first?.try &.is_a?(Crystal::BoolLiteral) ||
       node.obj.is_a?(Crystal::BoolLiteral)
     )
    @source.error @rule, node.location.try &.line_number,
      "Comparison to a boolean is pointless"
  end
end
