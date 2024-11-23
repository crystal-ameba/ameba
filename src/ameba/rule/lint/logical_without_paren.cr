module Ameba::Rule::Lint
  # A rule that disallows logical operators in method args without parenthesis.
  #
  # For example, this is considered invalid:
  #
  # ```
  # if a.includes? "b" && c.includes? "c"
  # end
  #
  # form.add "query", "val_1" || "val_2"
  # ```
  #
  # And need to be written as:
  #
  # ```
  # if a.includes?("b") && c.includes?("c")
  # end
  #
  # form.add("query", "val_1" || "val_2")
  # # OR
  # form.add "query", ("val_1" || "val_2")
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/LogicalWithoutParenthesis:
  #   Enabled: true
  # ```
  class LogicalWithoutParenthesis < Base
    properties do
      description "Disallows logical operators in method args without parenthesis"
    end

    MSG = "Logical operator in method args without parenthesis is not allowed"

    def test(source, node : Crystal::Call)
      return if node.args.size == 0 ||
                node.has_parentheses? ||
                node.name.ends_with?("=") ||
                node.name.in?(["[]?", "[]"])

      node.args.each do |arg|
        case arg
        when Crystal::BinaryOp
          issue_for arg, MSG
        end
      end
    end
  end
end
