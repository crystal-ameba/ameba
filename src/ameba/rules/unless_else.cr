# A rule that disallows the use of an `else` block with the `unless`.
#
# For example, the rule considers these valid:
#
# ```
# unless something
#   :ok
# end
#
# if something
#   :one
# else
#   :two
# end
# ```
#
# But it considers this one invalid as it is an `unless` with an `else`:
#
# ```
# unless something
#   :one
# else
#   :two
# end
# ```
#
# The solution is to swap the order of the blocks, and change the `unless` to
# an `if`, so the previous invalid example would become this:
#
# ```
# if something
#   :two
# else
#   :one
# end
# ```

Ameba.rule UnlessElse do |source|
  UnlessElseVisitor.new self, source
end

Ameba.visitor UnlessElse, Crystal::Unless do |node|
  unless node.else.is_a?(Crystal::Nop)
    @source.error @rule, node.location.try &.line_number,
      "Favour if over unless with else"
  end
end
