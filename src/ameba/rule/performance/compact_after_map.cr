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
    properties do
      description "Identifies usage of `compact` calls that follow `map`."
    end

    COMPACT_NAME = "compact"
    MAP_NAME     = "map"
    MSG          = "Use `compact_map {...}` instead of `map {...}.compact`"

    def test(source)
      AST::NodeVisitor.new self, source, skip: [
        Crystal::Macro,
        Crystal::MacroExpression,
        Crystal::MacroIf,
        Crystal::MacroFor,
      ]
    end

    def test(source, node : Crystal::Call)
      return unless node.name == COMPACT_NAME && (obj = node.obj)
      return unless obj.is_a?(Crystal::Call) && obj.block
      return unless obj.name == MAP_NAME

      issue_for obj.name_location, node.name_end_location, MSG
    end
  end
end
