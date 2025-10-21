require "./base"

module Ameba::Rule::Performance
  # This rule is used to identify usage of `any?` calls that follow filters.
  #
  # For example, this is considered invalid:
  #
  # ```
  # [1, 2, 3].select { |e| e > 2 }.any?
  # [1, 2, 3].reject { |e| e >= 2 }.any?
  # ```
  #
  # And it should be written as this:
  #
  # ```
  # [1, 2, 3].any? { |e| e > 2 }
  # [1, 2, 3].any? { |e| e < 2 }
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Performance/AnyAfterFilter:
  #   Enabled: true
  #   FilterNames:
  #     - select
  #     - reject
  # ```
  class AnyAfterFilter < Base
    include AST::Util

    properties do
      since_version "0.8.1"
      description "Identifies usage of `any?` calls that follow filters"
      filter_names %w[select reject]
    end

    MSG = "Use `any? {...}` instead of `%s {...}.any?`"

    def test(source, node : Crystal::Call)
      return unless node.name == "any?" && (obj = node.obj)
      return if has_block?(node)

      return unless obj.is_a?(Crystal::Call) && has_block?(obj)
      return unless obj.name.in?(filter_names)

      issue_for name_location(obj), name_end_location(node), MSG % obj.name
    end
  end
end
