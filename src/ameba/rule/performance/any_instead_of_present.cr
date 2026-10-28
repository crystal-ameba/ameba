require "./base"

module Ameba::Rule::Performance
  # This rule is used to identify usage of arg-less `Enumerable#any?` calls.
  #
  # Using `Enumerable#any?` instead of `Enumerable#present?` might lead to
  # unexpected results (like `[nil, false].any? # => false`). In some cases
  # it also might be less efficient, since it iterates until the block
  # returns a _truthy_ value, instead of just checking if there's at least
  # one value present.
  #
  # For example, this is considered invalid:
  #
  # ```
  # [1, 2, 3].any?
  # ```
  #
  # And it should be written as this:
  #
  # ```
  # [1, 2, 3].present?
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Performance/AnyInsteadOfPresent:
  #   Enabled: true
  # ```
  class AnyInsteadOfPresent < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Identifies usage of arg-less `any?` calls"
    end

    MSG = "Use `{...}.present?` instead of `{...}.any?`"

    def test(source)
      AST::NodeVisitor.new(self, source, skip: :macro)
    end

    def test(source, node : Crystal::Call)
      return unless node.name == "any?" && node.obj
      return if has_arguments?(node) || has_block?(node)

      name_location, end_location =
        name_location(node), name_end_location(node)

      unless name_location && end_location
        issue_for(node, MSG, prefer_name_location: true)
        return
      end

      issue_for(name_location, end_location, MSG) do |corrector|
        corrector.replace(name_location, end_location, "present?")
      end
    end
  end
end
