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

    # ameba:disable Metrics/CyclomaticComplexity
    def test(source)
      start_token = literal = delimiters = nil

      Tokenizer.new(source).run do |token|
        case token.type
        when .string_array_start?, .symbol_array_start?, .delimiter_start?
          if literal = token.raw.match(/^(%\w?)\W/i).try &.[1]
            start_token = token.dup

            delimiters =
              preferred_delimiters.fetch(literal) { default_delimiters }

            # `nil` means that the check should be skipped for this literal
            unless delimiters
              start_token = literal = delimiters = nil
            end
          end
        when .string?
          if (_delimiters = delimiters) && ignore_literals_containing_delimiters?
            # literal contains one or both delimiters
            if token.raw[_delimiters[0]]? || token.raw[_delimiters[1]]?
              start_token = literal = delimiters = nil
            end
          end
        when .string_array_end?, .delimiter_end?
          if (_start = start_token) && (_delimiters = delimiters) && (_literal = literal)
            unless _start.delimiter_state.nest == _delimiters[0] &&
                   _start.delimiter_state.end == _delimiters[1]
              token_location = {
                _start.location,
                _start.location.adjust(column_number: _literal.size - 1),
              }
              issue_for *token_location,
                MSG % {_literal, _delimiters[0], _delimiters[1]}
            end
            start_token = literal = delimiters = nil
          end
        end
      end
    end
  end
end
