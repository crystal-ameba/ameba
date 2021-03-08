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
    properties do
      description "Identifies usage of `flatten` calls that follow `map`."
    end

    FLATTEN_NAME = "flatten"
    MAP_NAME     = "map"
    MSG          = "Use `flat_map {...}` instead of `map {...}.flatten`"

    def test(source)
      AST::NodeVisitor.new self, source, skip: [
        Crystal::Macro,
        Crystal::MacroExpression,
        Crystal::MacroIf,
        Crystal::MacroFor,
      ]
    end

    def test(source, node : Crystal::Call)
      return unless node.name == FLATTEN_NAME && (obj = node.obj)
      return unless obj.is_a?(Crystal::Call) && obj.block
      return unless obj.name == MAP_NAME

      issue_for obj.name_location, node.name_end_location, MSG
    end
  end
end
