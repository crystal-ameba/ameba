module Ameba::Rule::Lint
  # A rule that disallows useless comparisons.
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
  # Lint/UselessComparison:
  #   Enabled: true
  # ```
  class UselessComparison < Base
    properties do
      description "Disallows useless comparison operations"
    end

    MSG = "Comparison operation has no effect"

    COMPARISON_OPERATORS = %w(
      == != =~ !~ ===
      < <= > >= <=>
      && ||
    )

    def test(source, node : Crystal::Expressions)
      last_idx = node.expressions.size - 1
      node.expressions.each_with_index do |exp, idx|
        next if idx == last_idx

        case exp
        when Crystal::Call
          if exp.name.in?(COMPARISON_OPERATORS) && exp.args.size == 1
            issue_for exp, MSG, prefer_name_location: true
          end
        end
      end
    end
  end
end
