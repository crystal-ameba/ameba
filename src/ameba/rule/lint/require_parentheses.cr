module Ameba::Rule::Lint
  # A rule that disallows method calls with at least one argument, where no
  # parentheses are used around the argument list, and a logical operator
  # (`&&` or `||`) is used within the argument list.
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
  # Lint/RequireParentheses:
  #   Enabled: true
  # ```
  class RequireParentheses < Base
    properties do
      since_version "1.7.0"
      description "Disallows method calls with no parentheses and a logical operator in the argument list"
    end

    MSG = "Use parentheses in the method call to avoid confusion about precedence"

    ALLOWED_CALL_NAMES = %w{[]? []}

    def test(source, node : Crystal::Call)
      return if node.args.empty? ||
                node.has_parentheses? ||
                node.name.ends_with?('=') ||
                node.name.in?(ALLOWED_CALL_NAMES)

      node.args.each do |arg|
        if arg.is_a?(Crystal::BinaryOp)
          if (right = arg.right).is_a?(Crystal::Call)
            issue_for node, MSG unless right.args.empty?
          end
        end
      end
    end
  end
end
