require "./base"

module Ameba::Rule::Performance
  # This rule is used to identify usage of `sum/product` calls
  # that follow `map`.
  #
  # For example, this is considered inefficient:
  #
  # ```
  # (1..3).map(&.*(2)).sum
  # ```
  #
  # And can be written as this:
  #
  # ```
  # (1..3).sum(&.*(2))
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Performance/MapInsteadOfBlock:
  #   Enabled: true
  # ```
  class MapInsteadOfBlock < Base
    include AST::Util

    properties do
      description "Identifies usage of `sum/product` calls that follow `map`"
    end

    MSG = "Use `%s {...}` instead of `map {...}.%s`"

    CALL_NAMES = %w[sum product]

    def test(source)
      AST::NodeVisitor.new self, source, skip: :macro
    end

    def test(source, node : Crystal::Call)
      return unless node.name.in?(CALL_NAMES) && (obj = node.obj)
      return unless obj.is_a?(Crystal::Call) && obj.block
      return unless obj.name == "map"

      issue_for name_location(obj), name_end_location(node),
        MSG % {node.name, node.name}
    end
  end
end
