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
      since_version "0.14.0"
      description "Identifies usage of `flatten` calls that follow `map`"
    end

    MSG = "Use `flat_map {...}` instead of `map {...}.flatten`"

    def test(source)
      AST::NodeVisitor.new(self, source, skip: :macro)
    end

    def test(source, node : Crystal::Call)
      return unless node.name == "flatten" && (obj = node.obj)
      return unless obj.is_a?(Crystal::Call) && has_block?(obj)
      return unless obj.name == "map"

      return unless name_location = name_location(obj)
      return unless name_location_end = name_end_location(obj)
      return unless end_location = name_end_location(node)

      issue_for(name_location, end_location, MSG) do |corrector|
        corrector.replace(name_location, name_location_end, "flat_map")
        corrector.remove_trailing(node, {{ ".flatten".size }})
      end
    end
  end
end
