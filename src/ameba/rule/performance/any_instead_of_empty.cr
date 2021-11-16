require "./base"

module Ameba::Rule::Performance
  # This rule is used to identify usage of arg-less `Enumerable#any?` calls.
  #
  # Using `Enumerable#any?` instead of `Enumerable#empty?` might lead to an
  # unexpected results (like `[nil, false].any? # => false`). In some cases
  # it also might be less efficient, since it iterates until the block will
  # return a _truthy_ value, instead of just checking if there's at least
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
  # ![1, 2, 3].empty?
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Performance/AnyInsteadOfEmpty:
  #   Enabled: true
  # ```
  class AnyInsteadOfEmpty < Base
    include AST::Util

    properties do
      description "Identifies usage of arg-less `any?` calls."
    end

    ANY_NAME = "any?"
    MSG      = "Use `!{...}.empty?` instead of `{...}.any?`"

    def test(source, node : Crystal::Call)
      return unless node.name == ANY_NAME
      return unless node.block.nil? && node.args.empty?
      return unless node.obj
      return unless location = node.location
      return unless name_location = node.name_location
      return unless end_location = name_end_location(node)

      issue_for location, end_location, MSG do |corrector|
        corrector.insert_before(location, '!')
        corrector.replace(name_location, end_location, "empty?")
      end
    end
  end
end
