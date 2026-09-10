require "./base"

module Ameba::Rule::Performance
  # This rule is used to identify usage of certain calls that follow `map` and
  # can be replaced with a single call - allowing to skip intermediate array
  # allocation.
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
  #   CallNames:
  #     - sum
  #     - product
  # ```
  class MapInsteadOfBlock < Base
    include AST::Util

    properties do
      since_version "0.14.0"
      description "Identifies usage of certain calls that follow `map` and can be replaced with a single call"
      call_names %w[sum product]
    end

    MSG = "Use `%s {...}` instead of `map {...}.%s`"

    def test(source)
      AST::NodeVisitor.new(self, source, skip: :macro)
    end

    def test(source, node : Crystal::Call)
      return unless node.name.in?(call_names) && (obj = node.obj)
      return unless obj.is_a?(Crystal::Call) && has_block?(obj)
      return unless obj.name == "map"

      issue_for name_location(obj), name_end_location(node),
        MSG % {node.name, node.name}
    end
  end
end
