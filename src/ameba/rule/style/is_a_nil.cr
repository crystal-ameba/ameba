module Ameba::Rule::Style
  # A rule that disallows calls to `is_a?(Nil)` in favor of `nil?`.
  #
  # This is considered bad:
  #
  # ```
  # var.is_a?(Nil)
  # ```
  #
  # And needs to be written as:
  #
  # ```
  # var.nil?
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/IsANil:
  #   Enabled: true
  # ```
  class IsANil < Base
    include AST::Util

    properties do
      description "Disallows calls to `is_a?(Nil)` in favor of `nil?`"
    end

    MSG = "Use `nil?` instead of `is_a?(Nil)`"

    def test(source, node : Crystal::IsA)
      return if node.nil_check?

      const = node.const
      return unless path_named?(const, "Nil")

      issue_for const, MSG do |corrector|
        corrector.replace(node, "#{node.obj}.nil?")
      end
    end
  end
end
