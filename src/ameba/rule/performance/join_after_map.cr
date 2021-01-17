module Ameba::Rule::Performance
  # This rule is used to identify usage of `join` calls that follow `map`.
  #
  # For example, this is considered inefficient:
  #
  # ```
  # (1..3).map(&.to_s).join('.')
  # ```
  #
  # And can be written as this:
  #
  # ```
  # (1..3).join('.', &.to_s)
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Performance/JoinAfterMap
  #   Enabled: true
  # ```
  struct JoinAfterMap < Base
    properties do
      description "Identifies usage of `join` calls that follow `map`."
    end

    MAP_NAME  = "map"
    JOIN_NAME = "join"
    MSG       = "Use `join(separator) {...}` instead of `map {...}.join(separator)`"

    def test(source)
      AST::NodeVisitor.new self, source, skip: [
        Crystal::Macro,
        Crystal::MacroExpression,
        Crystal::MacroIf,
        Crystal::MacroFor,
      ]
    end

    def test(source, node : Crystal::Call)
      return unless node.name == JOIN_NAME && (obj = node.obj)
      return unless obj.is_a?(Crystal::Call) && obj.block
      return unless obj.name == MAP_NAME

      issue_for obj.name_location, node.name_end_location, MSG
    end
  end
end
