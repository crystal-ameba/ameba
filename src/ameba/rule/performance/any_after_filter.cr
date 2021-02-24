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
    properties do
      description "Identifies usage of `any?` calls that follow filters."
      filter_names : Array(String) = %w(select reject)
    end

    ANY_NAME = "any?"
    MSG      = "Use `any? {...}` instead of `%s {...}.any?`"

    def test(source, node : Crystal::Call)
      return unless node.name == ANY_NAME && (obj = node.obj)
      return unless obj.is_a?(Crystal::Call) && obj.block && node.block.nil?
      return unless obj.name.in?(filter_names)

      issue_for obj.name_location, node.name_end_location, MSG % obj.name
    end
  end
end
