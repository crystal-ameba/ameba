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
    def visit(node : Crystal::If)
      if_node = node
      ifs = [] of Crystal::If

      loop do
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
