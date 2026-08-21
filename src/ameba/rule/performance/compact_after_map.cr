require "./base"

module Ameba::Rule::Performance
  # This rule is used to identify usage of `compact` calls that follow `map`.
  #
  # For example, this is considered inefficient:
  #
  # ```
  # %w[Alice Bob].map(&.match(/^A./)).compact
  # ```
  #
  # And can be written as this:
  #
  # ```
  # %w[Alice Bob].compact_map(&.match(/^A./))
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Performance/CompactAfterMap:
  #   Enabled: true
  # ```
  class CompactAfterMap < Base
    include AST::Util

    properties do
      since_version "0.14.0"
      description "Identifies usage of `compact` calls that follow `map`"
    end

    MSG = "Use `compact_map {...}` instead of `map {...}.compact`"

    def test(source)
      AST::NodeVisitor.new(self, source, skip: :macro)
    end

    def test(source, node : Crystal::Call)
      return unless node.name == "compact" && (obj = node.obj)
      return if has_arguments?(node) || has_block?(node)

      return unless obj.is_a?(Crystal::Call) && has_block?(obj)
      return if has_arguments?(obj)
      return unless obj.name == "map"

      return unless name_location = name_location(obj)
      return unless name_location_end = name_end_location(obj)
      return unless end_location = name_end_location(node)

      issue_for(name_location, end_location, MSG) do |corrector|
        corrector.replace(name_location, name_location_end, "compact_map")
        corrector.remove_trailing(node, {{ ".compact".size }})
      end
    end
  end
end
