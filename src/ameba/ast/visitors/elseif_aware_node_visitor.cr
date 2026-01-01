require "./node_visitor"

module Ameba::AST
  # A class that utilizes a logic inherited from `NodeVisitor` to traverse AST
  # nodes and fire a source test callback with the `Crystal::If` node and an array
  # containing all `elsif` branches (first branch is an `if` node) in case
  # at least one `elsif` branch is reached, and `nil` otherwise.
  #
  # In Crystal, consecutive `elsif` branches are transformed into `if` branches
  # attached to the `else` branch of an adjacent `if` branch.
  #
  # For example:
  #
  # ```
  # if foo
  #   do_foo
  # elsif bar
  #   do_bar
  # elsif baz
  #   do_baz
  # else
  #   do_something_else
  # end
  # ```
  #
  # is transformed into:
  #
  # ```
  # if foo
  #   do_foo
  # else
  #   if bar
  #     do_bar
  #   else
  #     if baz
  #       do_baz
  #     else
  #       do_something_else
  #     end
  #   end
  # end
  # ```
  class ElseIfAwareNodeVisitor < NodeVisitor
    include Util

    getter? exclude_ternary : Bool
    getter? exclude_suffix : Bool

    def initialize(rule, source, *, skip : Array | Category? = nil,
                   @exclude_ternary = true,
                   @exclude_suffix = true)
      super rule, source,
        skip: if skip.is_a?(Category)
          NodeVisitor.category_to_node_classes(skip)
        else
          skip
        end
    end

    def visit(node : Crystal::If)
      if_node = node
      ifs = [] of Crystal::If

      loop do
        break if exclude_ternary? && if_node.ternary?
        break if exclude_suffix? && suffix?(if_node)

        ifs << if_node

        if_node.cond.accept self
        if_node.then.accept self

        unless (if_node = if_node.else).is_a?(Crystal::If)
          if_node.accept self
          break
        end
      end

      @rule.test @source, node, (ifs if ifs.size > 1)
      false
    end
  end
end
