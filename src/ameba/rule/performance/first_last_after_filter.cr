require "./base"

module Ameba::Rule::Performance
  # This rule is used to identify usage of `first/last/first?/last?` calls that follow filters.
  #
  # For example, this is considered inefficient:
  #
  # ```
  # [-1, 0, 1, 2].select { |e| e > 0 }.first?
  # [-1, 0, 1, 2].select { |e| e > 0 }.last?
  # ```
  #
  # And can be written as this:
  #
  # ```
  # [-1, 0, 1, 2].find { |e| e > 0 }
  # [-1, 0, 1, 2].reverse_each.find { |e| e > 0 }
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Performance/FirstLastAfterFilter:
  #   Enabled: true
  #   FilterNames:
  #     - select
  # ```
  class FirstLastAfterFilter < Base
    include AST::Util

    properties do
      since_version "0.8.1"
      description "Identifies usage of `first/last/first?/last?` calls that follow filters"
      filter_names %w[select]
    end

    MSG         = "Use `find {...}` instead of `%s {...}.%s`"
    MSG_REVERSE = "Use `reverse_each.find {...}` instead of `%s {...}.%s`"

    CALL_NAMES = %w[first last first? last?]

    def test(source)
      AST::NodeVisitor.new self, source, skip: :macro
    end

    def test(source, node : Crystal::Call)
      return unless node.name.in?(CALL_NAMES) && node.args.empty?
      return if has_block?(node)

      return unless (obj = node.obj).is_a?(Crystal::Call)
      return unless obj.name.in?(filter_names) && has_block?(obj)

      message = node.name.includes?(CALL_NAMES.first) ? MSG : MSG_REVERSE

      issue_for name_location(obj), name_end_location(node),
        message % {obj.name, node.name}
    end
  end
end
