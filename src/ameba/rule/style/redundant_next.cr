module Ameba::Rule::Style
  # A rule that disallows redundant next expressions. A `next` keyword allows
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
  # ### YAML config example
  #
  # ```
  # Style/RedundantNext:
  #   Enabled: true
  # ```
  struct RedundantNext < Base
    properties do
      description "Reports redundant next expressions"
    end

    MSG = "Redundant `next` detected"

    def test(source)
      AST::NodeVisitor.new self, source
    end

    def test(source, node : Crystal::Block)
      AST::RedundantControlExpressionVisitor.new(self, source, node.body)
    end

    def test(source, node : Crystal::Next, visitor : AST::RedundantControlExpressionVisitor)
      source.try &.add_issue self, node, MSG
    end
  end
end
