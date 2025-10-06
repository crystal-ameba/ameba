module Ameba::Rule::Style
  # A rule that disallows usage of large numbers without underscore.
  # These do not affect the value of the number, but can help read
  # large numbers more easily.
  #
  # For example, these are considered invalid:
  #
  # ```
  # 100000
  # 141592654
  # 5.123456
  # ```
  #
  # And has to be rewritten as the following:
  #
  # ```
  # 100_000
  # 141_592_654
  # 5.123_456
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/LargeNumbers:
  #   Enabled: true
  #   IntMinDigits: 6 # i.e. integers higher than 99999
  # ```
  class LargeNumbers < Base
    include AST::Util

    properties do
      since_version "0.2.0"
      enabled false
      description "Disallows usage of large numbers without underscore"
      int_min_digits 6
    end

    MSG = "Large numbers should be written with underscores: `%s`"

    def test(source)
      Tokenizer.new(source).run do |token|
        next unless token.type.number? && decimal?(token.raw)

        parsed = parse_number(token.raw)

        if allowed?(*parsed) && (expected = underscored *parsed) != token.raw
          location = name_location_or(token, token.raw)

          issue_for *location, MSG % expected do |corrector|
            corrector.replace(*location, expected)
          end
        end
      end
    end

    private def decimal?(value)
      value !~ /^0(x|b|o)/
    end

    private def allowed?(_sign, value, fraction, _suffix)
      return true if fraction && fraction.size > 3

      digits = value.chars.select!(&.number?)
      digits.size >= int_min_digits
    end

    private def underscored(sign, value, fraction, suffix)
      value = slice_digits(value.reverse).reverse
      fraction = ".#{slice_digits(fraction)}" if fraction

      "#{sign}#{value}#{fraction}#{suffix}"
    end

    private def slice_digits(value, by = 3)
      %w[].tap do |slices|
        value.chars.reject!(&.== '_').each_slice(by) do |slice|
          slices << slice.join
        end
      end.join('_')
    end

    private def parse_number(value)
      value, sign = parse_sign(value)
      value, suffix = parse_suffix(value)
      value, fraction = parse_fraction(value)

      {sign, value, fraction, suffix}
    end

    private def parse_sign(value)
      if value[0].in?('+', '-')
        sign = value[0]
        value = value[1..-1]
      end
      {value, sign}
    end

    private def parse_suffix(value)
      if pos = (value =~ /(e|_?(i|u|f))/)
        suffix = value[pos..-1]
        value = value[0..pos - 1]
      end
      {value, suffix}
    end

    private def parse_fraction(value)
      if comma = value.index('.')
        fraction = value[comma + 1..-1]
        value = value[0..comma - 1]
      end
      {value, fraction}
    end
  end
end
