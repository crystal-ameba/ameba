module Ameba::Rule::Style
  # A rule that enforces the consistent usage of `%`-literal delimiters.
  #
  # Specifying `DefaultDelimiters` option will set all preferred delimiters at once. You
  # can continue to specify individual preferred delimiters via `PreferredDelimiters`
  # setting to override the default. In both cases the delimiters should be specified
  # as a string of two characters, or `nil` to ignore a particular `%`-literal / default.
  #
  # Setting `IgnoreLiteralsContainingDelimiters` to `true` will ignore `%`-literals that
  # contain one or both delimiters. Otherwise these are reported without being
  # autocorrected in case the delimiters are unbalanced within the literal
  # (i.e. `%w(a] b)`), since replacing the delimiters would make it invalid.
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

        if state.unbalanced_delimiters?
          issue_for(state.location, state.end_location, msg)
        else
          issue_for(state.location, state.end_location, msg) do |corrector|
            corrector.replace(x, x, state.opening_delimiter)
            corrector.replace(y, y, state.closing_delimiter)
          end
        end
      end
    end

    private class TokenProcessor
      def initialize(source, @rule : PercentLiteralDelimiters)
        @tokenizer = Tokenizer.new(source)
      end

      def run(&on_literal : LiteralState -> Nil) : Nil
        current_state = {} of Int32 => LiteralState
        nest_level = 0

        @tokenizer.run do |token|
          case token.type
          when .string_array_start?, .symbol_array_start?, .delimiter_start?
            nest_level += 1

            if literal = extract_percent_literal(token.raw)
              if delimiters = delimiters_for_literal(literal)
                current_state[nest_level] = LiteralState.new(token, literal, delimiters)
              end
            end
          when .string?
            if (state = current_state[nest_level]?) && state.includes_delimiters?(token.raw)
              if @rule.ignore_literals_containing_delimiters?
                current_state.delete(nest_level)
              else
                state.track_delimiters(token.raw)
              end
            end
          when .string_array_end?, .delimiter_end?
            if state = current_state.delete(nest_level)
              unless state.correct_delimiters?
                state.end_token = token
                on_literal.call(state)
              end
            end

            nest_level -= 1
          end
        end
      end

      private def extract_percent_literal(string)
        string.match(/^(%\w*)\W/).try(&.[1])
      end

      private def delimiters_for_literal(literal)
        @rule.preferred_delimiters.fetch(literal) { @rule.default_delimiters }
      end

      class LiteralState
        getter start_token : Crystal::Token
        property! end_token : Crystal::Token
        getter literal : String
        getter opening_delimiter : Char
        getter closing_delimiter : Char

        # Nesting depth of the preferred delimiters within the literal contents,
        # and whether it went below zero at any point
        @delimiters_depth = 0
        @delimiters_underflow = false

        def initialize(@start_token, @literal, delimiters)
          @opening_delimiter = delimiters[0]
          @closing_delimiter = delimiters[1]
        end

        def includes_delimiters?(string)
          string.includes?(opening_delimiter) ||
            string.includes?(closing_delimiter)
        end

        # Tracks the preferred delimiters contained within the given *string*
        # (a part of the literal contents).
        def track_delimiters(string) : Nil
          escaped = false
          string.each_char do |char|
            case
            when escaped
              escaped = false
            when char == '\\'
              escaped = true
            when char == opening_delimiter
              @delimiters_depth += 1
            when char == closing_delimiter
              @delimiters_depth -= 1
              @delimiters_underflow = true if @delimiters_depth.negative?
            end
          end
        end

        # Returns `true` if the preferred delimiters within the literal contents
        # are unbalanced, which makes them unusable as the literal delimiters.
        def unbalanced_delimiters?
          @delimiters_underflow || !@delimiters_depth.zero?
        end

        def correct_delimiters?
          start_token.delimiter_state.nest == opening_delimiter &&
            start_token.delimiter_state.end == closing_delimiter
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
