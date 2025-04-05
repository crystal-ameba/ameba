module Ameba::Rule::Lint
  # Checks if specs are focused.
  #
  # In specs `focus: true` is mainly used to focus on a spec
  # item locally during development. However, if such change
  # is committed, it silently runs only focused spec on all
  # other environment, which is undesired.
  #
  # This is considered bad:
  #
  # ```
  # describe MyClass, focus: true do
  # end
  #
  # describe ".new", focus: true do
  # end
  #
  # context "my context", focus: true do
  # end
  #
  # it "works", focus: true do
  # end
  # ```
  #
  # And it should be written as the following:
  #
  # ```
  # describe MyClass do
  # end
  #
  # describe ".new" do
  # end
  #
  # context "my context" do
  # end
  #
  # it "works" do
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/SpecFocus:
  #   Enabled: true
  # ```
  class SpecFocus < Base
    properties do
      since_version "0.14.0"
      description "Reports focused spec items"
    end

    MSG = "Focused spec item detected"

    SPEC_ITEM_NAMES = %w[describe context it pending]

    def test(source)
      return unless source.spec?

      AST::NodeVisitor.new self, source
    end

    def test(source, node : Crystal::Call)
      return unless node.name.in?(SPEC_ITEM_NAMES)
      return unless node.block

      arg = node.named_args.try &.find(&.name.== "focus")
      return if arg.nil? ||
                arg.value.is_a?(Crystal::Call) ||
                arg.value.is_a?(Crystal::Var)

      issue_for arg, MSG
    end
  end
end
