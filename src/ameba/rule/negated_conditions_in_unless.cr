module Ameba::Rule
  # A rule that disallows negated conditions in unless.
  #
  # For example, this is considered invalid:
  #
  # ```
  # unless !s.empty?
  #   :ok
  # end
  # ```
  #
  # And should be rewritten to the following:
  #
  # ```
  # if s.emtpy?
  #   :ok
  # end
  # ```
  #
  # It is pretty difficult to wrap your head around a block of code
  # that is executed if a negated condition is NOT met.
  #
  struct NegatedConditionsInUnless < Base
    def test(source)
      AST::Visitor.new self, source
    end

    def test(source, node : Crystal::Unless)
      return unless negated_condition? node.cond
      source.error self, node.location,
        "Avoid negated conditions in unless blocks"
    end

    private def negated_condition?(node)
      case node
      when Crystal::BinaryOp
        negated_condition?(node.left) || negated_condition?(node.right)
      when Crystal::Expressions
        node.expressions.any? { |e| negated_condition? e }
      when Crystal::Not
        true
      else
        false
      end
    end
  end
end
