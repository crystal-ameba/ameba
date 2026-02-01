module Ameba::Rule::Style
  # A rule that enforces the consistent usage of `%`-literal delimiters.
  #
  # Specifying `DefaultDelimiters` option will set all preferred delimiters at once. You
  # can continue to specify individual preferred delimiters via `PreferredDelimiters`
  # setting to override the default. In both cases the delimiters should be specified
  # as a string of two characters, or `nil` to ignore a particular `%`-literal / default.
  #
  # Setting `IgnoreLiteralsContainingDelimiters` to `true` will ignore `%`-literals that
  # contain one or both delimiters.
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

    MSG = "`%s`-literals should be delimited by `%s` and `%s`"

    def test(source)
      processor = TokenProcessor.new(source, self)
      processor.run do |state|
        msg = MSG % {state.literal, state.opening_delimiter, state.closing_delimiter}

        x = state.start_token.location.adjust(column_number: state.literal.size)
        y = state.end_token.location

        issue_for state.location, state.end_location, msg do |corrector|
          corrector.replace(x, x, state.opening_delimiter)
          corrector.replace(y, y, state.closing_delimiter)
        end
      end
    end

    private class TokenProcessor
      def initialize(source, @rule : PercentLiteralDelimiters)
        @tokenizer = Tokenizer.new(source)
      end

      def run(&on_literal : LiteralState -> Nil) : Nil
        current_state = nil

        @tokenizer.run do |token|
          case token.type
          when .string_array_start?, .symbol_array_start?, .delimiter_start?
            if literal = extract_percent_literal(token.raw)
              if delimiters = delimiters_for_literal(literal)
                current_state = LiteralState.new(token.dup, literal, delimiters)
              end
            end
          when .string?
            if (state = current_state) && @rule.ignore_literals_containing_delimiters?
              current_state = nil if state.includes_delimiters?(token.raw)
            end
          when .string_array_end?, .delimiter_end?
            if state = current_state
              unless state.correct_delimiters?
                state.end_token = token
                on_literal.call(state)
              end
              current_state = nil
            end
          end
        end
      end

      private def extract_percent_literal(string)
        string.match(/^(%\w*)\W/).try &.[1]
      end

      private def delimiters_for_literal(literal)
        @rule.preferred_delimiters.fetch(literal) { @rule.default_delimiters }
      end

      struct LiteralState
        getter start_token : Crystal::Token
        property! end_token : Crystal::Token
        getter literal : String
        getter opening_delimiter : Char
        getter closing_delimiter : Char

        def initialize(@start_token, @literal, delimiters)
          @opening_delimiter = delimiters[0]
          @closing_delimiter = delimiters[1]
        end

        def includes_delimiters?(string)
          string.includes?(opening_delimiter) ||
            string.includes?(closing_delimiter)
        end

        def correct_delimiters?
          start_token.delimiter_state.nest.as(Char) == opening_delimiter &&
            start_token.delimiter_state.end.as(Char) == closing_delimiter
        end

        def location
          start_token.location
        end

        def end_location
          location.adjust(column_number: literal.size - 1)
        end
      end
    end
  end
end
