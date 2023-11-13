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
      description "Identifies usage of `compact` calls that follow `map`"
    end

    MSG = "Use `compact_map {...}` instead of `map {...}.compact`"

    def test(source)
      AST::NodeVisitor.new self, source, skip: :macro
    end

    def test(source, node : Crystal::Call)
      return unless node.name == "compact" && (obj = node.obj)
      return unless obj.is_a?(Crystal::Call) && obj.block
      return unless obj.name == "map"

      issue_for name_location(obj), name_end_location(node), MSG
    end
  end
end
