require "./base"

module Ameba::Rule::Performance
  # This rule is used to identify usage of `any?` calls that follow `map/select/reject` filters.
  #
  # For example, this is considered invalid:
  #
  # ```
  # [1, 2, 3].map { |e| e if e > 2 }.any?
  # [1, 2, 3].select { |e| e > 2 }.any?
  # [1, 2, 3].reject { |e| e > 2 }.any?
  # ```
  #
  # And it should be written as this:
  #
  # ```
  # [1, 2, 3].any? { |e| e > 2 }
  # [1, 2, 3].any? { |e| e > 2 }
  # [1, 2, 3].any? { |e| e <= 2 }
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Performance/AnyAfterFilter:
  #   Enabled: true
  # ```
  class AnyAfterFilter < Base
    include AST::Util

    properties do
      since_version "0.8.1"
      description "Identifies usage of `any?` calls that follow `map/select/reject` filters"
    end

    MSG = "Use `any? {%s}` instead of `%s {...}.any?`"

    # ameba:disable Metrics/CyclomaticComplexity
    def test(source, node : Crystal::Call)
      return unless node.name == "any?" && (obj = node.obj)
      return if has_block?(node) || has_arguments?(node)

      return unless obj.is_a?(Crystal::Call) && has_block?(obj)
      return unless obj.name.in?("map", "select", "reject")
      return if has_arguments?(obj)

      return unless node_name_end_location = name_end_location(node)
      return unless name_location = name_location(obj)
      return unless name_end_location = name_end_location(obj)

      issue_location =
        {name_location, node_name_end_location}

      case obj.name
      when "select", "map"
        issue_for(*issue_location, MSG % {"...", obj.name}) do |corrector|
          corrector.replace(name_location, name_end_location, "any?")
          corrector.remove_trailing(node, {{ ".any?".size }})
        end
      when "reject"
        issue_for(*issue_location, MSG % {"!...", obj.name})
      end
    end
  end
end
