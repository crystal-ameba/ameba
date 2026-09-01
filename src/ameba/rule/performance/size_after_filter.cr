require "./base"

module Ameba::Rule::Performance
  # This rule is used to identify usage of `size` calls that follow filter.
  #
  # For example, this is considered invalid:
  #
  # ```
  # [1, 2, 3].select { |e| e > 2 }.size
  # [1, 2, 3].reject { |e| e < 2 }.size
  # [1, 2, 3].select(&.< 2).size
  # [0, 1, 2].select(&.zero?).size
  # [0, 1, 2].reject(&.zero?).size
  # ```
  #
  # And it should be written as this:
  #
  # ```
  # [1, 2, 3].count { |e| e > 2 }
  # [1, 2, 3].count { |e| e >= 2 }
  # [1, 2, 3].count(&.< 2)
  # [0, 1, 2].count(&.zero?)
  # [0, 1, 2].count(&.!= 0)
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Performance/SizeAfterFilter:
  #   Enabled: true
  #   FilterNames:
  #     - select
  #     - reject
  # ```
  class SizeAfterFilter < Base
    include AST::Util

    properties do
      since_version "0.8.1"
      description "Identifies usage of `size` calls that follow filter"
      filter_names %w[select reject]
    end

    MSG = "Use `count {...}` instead of `%s {...}.size`"

    def test(source)
      AST::NodeVisitor.new(self, source, skip: :macro)
    end

    def test(source, node : Crystal::Call)
      return unless node.name == "size" && (obj = node.obj)
      return unless obj.is_a?(Crystal::Call) && has_block?(obj)
      return unless obj.name.in?(filter_names)

      return unless name_location = name_location(obj)
      return unless name_location_end = name_end_location(obj)
      return unless end_location = name_end_location(node)

      issue_for(name_location, end_location, MSG % obj.name) do |corrector|
        corrector.replace(name_location, name_location_end, "count")
        corrector.remove_trailing(node, {{ ".size".size }})
      end
    end
  end
end
