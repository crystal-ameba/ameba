module Ameba::Rule::Lint
  # A rule that disallows some unwanted symbols in percent array literals.
  #
  # For example, this is usually written by mistake:
  #
  # ```
  # %i[:one, :two]
  # %w["one", "two"]
  # ```
  #
  # And the expected example is:
  #
  # ```
  # %i[one two]
  # %w[one two]
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/PercentArrays:
  #   Enabled: true
  #   StringArrayUnwantedSymbols: ',"'
  #   SymbolArrayUnwantedSymbols: ',:'
  # ```
  class PercentArrays < Base
    properties do
      description "Disallows some unwanted symbols in percent array literals"

      string_array_unwanted_symbols %(,")
      symbol_array_unwanted_symbols %(,:)
    end

    MSG = "Symbols `%s` may be unwanted in %s array literals"

    def test(source)
      issue = start_token = nil

      Tokenizer.new(source).run do |token|
        case token.type
        when .string_array_start?, .symbol_array_start?
          start_token = token.dup
        when .string?
          if (_start = start_token) && !issue
            issue = array_entry_invalid?(token.value.to_s, _start.raw)
          end
        when .string_array_end?
          if (_start = start_token) && (_issue = issue)
            issue_for _start, _issue
          end
          issue = start_token = nil
        end
      end
    end

    private def array_entry_invalid?(entry, array_type)
      case array_type
      when .starts_with? "%w"
        check_array_entry entry, string_array_unwanted_symbols, "%w"
      when .starts_with? "%i"
        check_array_entry entry, symbol_array_unwanted_symbols, "%i"
      end
    end

    private def check_array_entry(entry, symbols, literal)
      MSG % {symbols, literal} if entry.matches?(/[#{Regex.escape(symbols)}]/)
    end
  end
end
