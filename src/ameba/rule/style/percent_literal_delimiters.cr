module Ameba::Rule::Style
  # A rule that enforces the consistent usage of `%`-literal delimiters.
  #
  # Configuration options:
  # - `DefaultDelimiters`: Sets preferred delimiters for all literals (e.g. "()")
  # - `PreferredDelimiters`: Override defaults for specific literals (e.g. "%w" => "[]")
  # - `IgnoreLiteralsContainingDelimiters`: Skip check if literal contains delimiters
  #
  # YAML configuration example:
  #
  # ```
  # Style/PercentLiteralDelimiters:
  #   Enabled: true
  #   DefaultDelimiters: '()'
  #   PreferredDelimiters:
  #     '%w': '[]'
  #     '%i': '[]'
  #     '%r': '{}'
  #   IgnoreLiteralsContainingDelimiters: false
  # ```
  class PercentLiteralDelimiters < Base
    properties do
      since_version "1.7.0"
      description "Enforces the consistent usage of `%`-literal delimiters"

      default_delimiters "()", as: String?
      preferred_delimiters({
        "%w" => "[]",
        "%i" => "[]",
        "%r" => "{}",
      } of String => String?)
      ignore_literals_containing_delimiters false
    end

    LITERAL_PATTERN = /^(%\w?)\W/i
    MSG             = "`%s`-literals should be delimited by `%s` and `%s`"

    def test(source)
      token_processor = TokenProcessor.new(self, source)
      Tokenizer.new(source).run { |token| token_processor.process(token) }
    end

    private struct LiteralState
      getter start_token : Crystal::Token
      getter literal : String
      getter delimiters : String

      def initialize(@start_token, @literal, @delimiters)
      end
    end

    private class TokenProcessor
      @current_state : LiteralState?

      def initialize(@rule : PercentLiteralDelimiters, @source : Source)
      end

      def process(token : Crystal::Token)
        case token.type
        when .string_array_start?, .symbol_array_start?, .delimiter_start?
          process_literal_start(token)
        when .string?
          process_string_content(token)
        when .string_array_end?, .delimiter_end?
          process_literal_end(token)
        end
      end

      private def process_literal_start(token : Crystal::Token)
        return unless literal = extract_literal(token)
        return unless delimiters = get_delimiters(literal)

        @current_state = LiteralState.new(token.dup, literal, delimiters)
      end

      private def process_string_content(token : Crystal::Token)
        return unless state = @current_state
        return unless @rule.ignore_literals_containing_delimiters?

        if contains_delimiters?(token.raw, state.delimiters)
          @current_state = nil
        end
      end

      private def process_literal_end(token : Crystal::Token)
        return unless state = @current_state
        check_delimiters(token, state)
        @current_state = nil
      end

      private def extract_literal(token : Crystal::Token)
        token.raw.match(LITERAL_PATTERN).try &.[1]
      end

      private def get_delimiters(literal : String)
        @rule.preferred_delimiters.fetch(literal) { @rule.default_delimiters }
      end

      private def contains_delimiters?(content : String, delimiters : String)
        content.includes?(delimiters[0]) || content.includes?(delimiters[1])
      end

      private def check_delimiters(token : Crystal::Token, state : LiteralState)
        start_state = state.start_token.delimiter_state
        expected_delimiters = state.delimiters

        unless correct_delimiters?(start_state, expected_delimiters)
          report_issue(state)
        end
      end

      private def correct_delimiters?(state, delimiters : String)
        state.nest == delimiters[0] && state.end == delimiters[1]
      end

      private def report_issue(state : LiteralState)
        start_location = state.start_token.location
        end_location = state.start_token.location.adjust(
          column_number: state.literal.size - 1
        )

        @source.add_issue(
          @rule,
          start_location,
          end_location,
          MSG % {state.literal, state.delimiters[0], state.delimiters[1]}
        )
      end
    end
  end
end
