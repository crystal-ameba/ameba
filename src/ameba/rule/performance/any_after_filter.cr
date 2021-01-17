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
  struct AnyAfterFilter < Base
    ANY_NAME = "any?"
    MSG      = "Use `any? {...}` instead of `%s {...}.any?`"

    properties do
      filter_names : Array(String) = %w(select reject)
      description "Identifies usage of `any?` calls that follow filters."
    end

    def test(source, node : Crystal::Call)
      return unless node.name == ANY_NAME && (obj = node.obj)
      return unless obj.is_a?(Crystal::Call)
      return if obj.block.nil? || !node.block.nil?

      if filter_names.includes?(obj.name)
        issue_for obj.name_location, node.name_end_location, MSG % obj.name
      end
    end
  end
end
