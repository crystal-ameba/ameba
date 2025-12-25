module Ameba::Rule::Style
  # A rule that enforces usage of parentheses in method or macro calls.
  #
  # For example, this (and all of its variants) is considered invalid:
  #
  # ```
  # user.update name: "John", age: 30
  # ```
  #
  # And should be replaced by the following:
  #
  # ```
  # user.update(name: "John", age: 30)
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/CallParentheses:
  #   Enabled: true
  # ```
  class CallParentheses < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Enforces usage of parentheses in method calls"
      enabled false
    end

    MSG = "Missing parentheses in method call"

    def test(source, node : Crystal::Call)
      return if node.args_in_brackets? ||
                node.has_parentheses? ||
                node.expansion? ||
                operator_method?(node) ||
                node.name.ends_with?('=')

      # foo.bar baz: 42 do |what, is|
      #        ^--- x  ^--- y
      #   # ...
      # end

      x = name_end_location(node).try(&.adjust(column_number: 1))

      if block = node.block
        if short_block?(block, source)
          y = block.body.end_location.try(&.adjust(column_number: 1))
        end
        y ||= node.block.try(&.location.try(&.adjust(column_number: -1)))
      else
        y = node.end_location.try(&.adjust(column_number: 1))
      end

      if x && y
        return unless y > x

        issue_for node, MSG do |corrector|
          corrector.replace(x, x, "(")
          corrector.insert_before(y, ")")
        end
      else
        issue_for node, MSG
      end
    end
  end
end
