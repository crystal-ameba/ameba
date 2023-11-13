require "./base"

module Ameba::Rule::Performance
  # This rule is used to identify usage of `flatten` calls that follow `map`.
  #
  # For example, this is considered inefficient:
  #
  # ```
  # %w[Alice Bob].map(&.chars).flatten
  # ```
  #
  # And can be written as this:
  #
  # ```
  # %w[Alice Bob].flat_map(&.chars)
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Performance/FlattenAfterMap:
  #   Enabled: true
  # ```
  class FlattenAfterMap < Base
    include AST::Util

    properties do
      description "Identifies usage of `flatten` calls that follow `map`"
    end

    MSG = "Use `flat_map {...}` instead of `map {...}.flatten`"

    def test(source)
      AST::NodeVisitor.new self, source, skip: :macro
    end

    def test(source, node : Crystal::Call)
      return unless node.name == "flatten" && (obj = node.obj)
      return unless obj.is_a?(Crystal::Call) && obj.block
      return unless obj.name == "map"

      issue_for name_location(obj), name_end_location(node), MSG
    end
  end
end
