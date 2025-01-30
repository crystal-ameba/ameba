module Ameba::Rule::Style
  # A rule that disallows redundant `next` expressions. A `next` keyword allows
  # a block to skip to the next iteration early, however, it is considered
  # redundant in cases where it is the last expression in a block or combines
  # into the node which is the last in a block.
  #
  # For example, this is considered invalid:
  #
  # ```
  # block do |v|
  #   next v + 1
  # end
  # ```
  #
  # ```
  # block do |v|
  #   case v
  #   when .nil?
  #     next "nil"
  #   when .blank?
  #     next "blank"
  #   else
  #     next "empty"
  #   end
  # end
  # ```
  #
  # And has to be written as the following:
  #
  # ```
  # block do |v|
  #   v + 1
  # end
  # ```
  #
  # ```
  # block do |v|
  #   case arg
  #   when .nil?
  #     "nil"
  #   when .blank?
  #     "blank"
  #   else
  #     "empty"
  #   end
  # end
  # ```
  #
  # ### Configuration params
  #
  # 1. *allow_multi_next*, default: true
  #
  # Allows end-user to configure whether to report or not the `next` statements
  # which yield tuple literals i.e.
  #
  # ```
  # block do
  #   next a, b
  # end
  # ```
  #
  # If this param equals to `false`, the block above will be forced to be written as:
  #
  # ```
  # block do
  #   {a, b}
  # end
  # ```
  #
  # 2. *allow_empty_next*, default: true
  #
  # Allows end-user to configure whether to report or not the `next` statements
  # without arguments. Sometimes such statements are used to yield the `nil` value explicitly.
  #
  # ```
  # block do
  #   @foo = :empty
  #   next
  # end
  # ```
  #
  # If this param equals to `false`, the block above will be forced to be written as:
  #
  # ```
  # block do
  #   @foo = :empty
  #   nil
  # end
  # ```
  #
  # ### YAML config example
  #
  # ```
  # Style/RedundantNext:
  #   Enabled: true
  #   AllowMultiNext: true
  #   AllowEmptyNext: true
  # ```
  class RedundantNext < Base
    include AST::Util

    properties do
      since_version "0.12.0"
      description "Reports redundant `next` expressions"

      allow_multi_next true
      allow_empty_next true
    end

    MSG = "Redundant `next` detected"

    def test(source, node : Crystal::Block)
      AST::RedundantControlExpressionVisitor.new(self, source, node.body)
    end

    def test(source, node : Crystal::Next, visitor : AST::RedundantControlExpressionVisitor)
      return if allow_multi_next? && node.exp.is_a?(Crystal::TupleLiteral)
      return if allow_empty_next? && (node.exp.nil? || node.exp.try(&.nop?))

      if exp_code = control_exp_code(node, source.lines)
        issue_for node, MSG do |corrector|
          corrector.replace(node, exp_code)
        end
      else
        issue_for node, MSG
      end
    end
  end
end
