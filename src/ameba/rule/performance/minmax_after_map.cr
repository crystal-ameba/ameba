require "./base"

module Ameba::Rule::Performance
  # This rule is used to identify usage of `min/max/minmax` calls that follow `map`.
  #
  # For example, this is considered invalid:
  #
  # ```
  # %w[Alice Bob].map(&.size).min
  # %w[Alice Bob].map(&.size).max
  # %w[Alice Bob].map(&.size).minmax
  # ```
  #
  # And it should be written as this:
  #
  # ```
  # %w[Alice Bob].min_of(&.size)
  # %w[Alice Bob].max_of(&.size)
  # %w[Alice Bob].minmax_of(&.size)
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Performance/MinMaxAfterMap:
  #   Enabled: true
  # ```
  class MinMaxAfterMap < Base
    include AST::Util

    properties do
      description "Identifies usage of `min/max/minmax` calls that follow `map`"
    end

    MSG        = "Use `%s {...}` instead of `map {...}.%s`."
    CALL_NAMES = %w[min min? max max? minmax minmax?]

    def test(source)
      AST::NodeVisitor.new self, source, skip: :macro
    end

    def test(source, node : Crystal::Call)
      return unless node.name.in?(CALL_NAMES) && node.block.nil? && node.args.empty?
      return unless (obj = node.obj) && obj.is_a?(Crystal::Call)
      return unless obj.name == "map" && obj.block && obj.args.empty?

      return unless name_location = name_location(obj)
      return unless end_location = name_end_location(node)

      of_name = node.name.sub(/(.+?)(\?)?$/, "\\1_of\\2")
      message = MSG % {of_name, node.name}

      issue_for name_location, end_location, message do |corrector|
        next unless node_name_location = name_location(node)

        # TODO: switching the order of the below calls breaks the corrector
        corrector.replace(
          name_location,
          name_location.adjust(column_number: {{ "map".size - 1 }}),
          of_name
        )
        corrector.remove(
          node_name_location.adjust(column_number: -1),
          end_location
        )
      end
    end
  end
end
