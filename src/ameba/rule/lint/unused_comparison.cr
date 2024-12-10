module Ameba::Rule::Lint
  # A rule that disallows unused comparisons.
  #
  # For example, this is considered invalid:
  #
  # ```
  # a = obj.method do |x|
  #   x == 1 # => Comparison operation has no effect
  #   puts x
  # end
  #
  # b = if a >= 0
  #       c < 1 # => Comparison operation has no effect
  #       "hello world"
  #     end
  # ```
  #
  # And these are considered valid:
  #
  # ```
  # a = obj.method do |x|
  #   x == 1
  # end
  #
  # b = if a >= 0 &&
  #        c < 1
  #       "hello world"
  #     end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/UnusedComparison:
  #   Enabled: true
  # ```
  class UnusedComparison < Base
    properties do
      since_version "1.7.0"
      description "Disallows unused comparison operations"
    end

    MSG = "Comparison operation is unused"

    COMPARISON_OPERATORS = %w[
      == != =~ !~ ===
      < <= > >= <=>
    ]

    def test(source : Source)
      AST::ImplicitReturnVisitor.new(self, source)
    end

    def test(source, node : Crystal::Call, last_is_used : Bool)
      if !last_is_used && node.name.in?(COMPARISON_OPERATORS) && node.args.size == 1
        return if node.name.in?("===", "=~") &&
                  (node.obj.is_a?(Crystal::RegexLiteral) || node.args.first.is_a?(Crystal::RegexLiteral))

        issue_for node, MSG
      end
    end
  end
end
