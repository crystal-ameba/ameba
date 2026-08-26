module Ameba::Rule::Style
  # Disallows chaining method calls directly after multi-line `do`...`end`
  # blocks, since the resulting code is difficult to read.
  #
  # For example, this is considered invalid:
  #
  # ```
  # items do
  #   # ...
  # end.compact
  # ```
  #
  # And should instead be written as:
  #
  # ```
  # result = items do
  #   # ...
  # end
  #
  # result.compact
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/MethodCallAfterMultilineBlock:
  #   Enabled: true
  # ```
  class MethodCallAfterMultilineBlock < Base
    include AST::Util

    properties do
      description "Disallows method calls after multi-line `do`...`end` blocks"
      enabled false
    end

    MSG = "Avoid chaining a method call on a do...end block"

    def test(source, node : Crystal::Call)
      return unless receiver = node.obj.as?(Crystal::Call)
      return unless block = receiver.block
      return unless location = block.location
      return unless end_location = block.end_location
      return if location.same_line?(end_location)
      return unless source.code[source.pos(location)]? == 'd'

      issue_for(name_location_or(node), MSG)
    end
  end
end
