module Ameba::Rule::Style
  # A rule that disallows negated conditions in `unless`.
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
  # if s.empty?
  #   :ok
  # end
  # ```
  #
  # It is pretty difficult to wrap your head around a block of code
  # that is executed if a negated condition is NOT met.
  #
  # YAML configuration example:
  #
  # ```
  # Style/NegatedConditionsInUnless:
  #   Enabled: true
  # ```
  class NegatedConditionsInUnless < Base
    properties do
      since_version "0.2.0"
      description "Disallows negated conditions in `unless`"
    end

    MSG = "Avoid negated conditions in `unless` blocks"

    def test(source, node : Crystal::Unless)
      cond = node.cond
      return unless negated_condition?(cond)

      if cond.is_a?(Crystal::Not)
        issue_for(cond, MSG) do |corrector|
          correct(corrector, source, node, cond)
        end
      else
        issue_for(cond, MSG)
      end
    end

    private def correct(corrector, source, node, not_node)
      return unless node_location = node.location
      return unless not_location = not_node.location
      return unless keyword_location = keyword_location(source, node_location, not_location)

      keyword_end_location =
        keyword_location.adjust(column_number: {{ "unless".size - 1 }})

      corrector.replace(keyword_location, keyword_end_location, "if")
      corrector.remove(not_location, not_location)
    end

    # The `unless` keyword is directly followed by the negated condition,
    # both in the regular and in the suffix form, so it's the last token
    # (skipping whitespace and comments) preceding the condition
    private def keyword_location(source, node_location, not_location)
      code = source.code[source.pos(node_location)...source.pos(not_location)]
      last_token = nil

      lexer = Crystal::Lexer.new(code)
      completed = Tokenizer.new(lexer).run do |token|
        next if token.type.space? || token.type.newline? || token.type.eof?
        last_token = token
      end
      return unless completed
      return unless token = last_token
      return unless token.value == Crystal::Keyword::UNLESS

      node_location.seek(token.location)
    end

    private def negated_condition?(node)
      case node
      when Crystal::BinaryOp
        negated_condition?(node.left) || negated_condition?(node.right)
      when Crystal::Expressions
        node.expressions.any? { |exp| negated_condition?(exp) }
      when Crystal::Not
        true
      else
        false
      end
    end
  end
end
