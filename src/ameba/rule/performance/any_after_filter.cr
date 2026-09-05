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
      return unless valid_call?(node) && (obj = node.obj)
      return unless obj.is_a?(Crystal::Call) && valid_filter?(obj)

      return unless name_location = name_location(obj)
      return unless end_location = name_end_location(node)

      report_issue(source, name_location, end_location, obj, node)
    end

    private def valid_call?(node)
      node.name == "any?" && !has_block?(node) && !has_arguments?(node) && !node.has_parentheses?
    end

    private def valid_filter?(obj : Crystal::Call)
      has_block?(obj) && obj.name.in?(filter_names) && !has_arguments?(obj)
    end

    private def report_issue(source, name_location, end_location, obj : Crystal::Call, node)
      if obj.name == "select" && (name_location_end = name_end_location(obj))
        issue_for(name_location, end_location, MSG % obj.name) do |corrector|
          corrector.replace(name_location, name_location_end, "any?")
          corrector.remove_trailing(node, {{ ".any?".size }})
        end
      else
        issue_for(name_location, end_location, MSG % obj.name)
      end
    end
  end
end
