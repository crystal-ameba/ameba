module Ameba::Rule::Lint
  # A rule that disallows logical operators in method args without parenthesis.
  #
  # For example, this is considered invalid:
  #
  # ```
  # if foo.includes? "bar" || foo.includes? "batz"
  # end
  # ```
  #
  # And need to be written as:
  #
  # ```
  # if foo.includes?("bar") || foo.includes?("batz")
  # end
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
        if arg.is_a?(Crystal::BinaryOp)
          case right = arg.right
          when Crystal::Call
            if right.args.size > 0
              issue_for node, MSG
            end
          end
        end
      end
    end
  end
end
