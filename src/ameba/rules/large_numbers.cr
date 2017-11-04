module Ameba::Rules
  # A rule that disallows usage of large numbers without underscore.
  # These do not affect the value of the number, but can help read
  # large numbers more easily.
  #
  # For example, these are considered invalid:
  #
  # ```
  # 10000
  # 141592654
  # 5.12345
  # ```
  #
  # And has to be rewritten as the following:
  #
  # ```
  # 10_000
  # 141_592_654
  # 5.123_45
  # ```
  #
  struct LargeNumbers < Rule
    def test(source)
      Tokenizer.new(source).run do |token|
        next unless token.type == :NUMBER && decimal?(token.raw)

        if (expected = underscored token.raw) != token.raw
          source.error self, token.line_number,
            "Large numbers should be written with underscores: #{expected}"
        end
      end
    end

    private def decimal?(value)
      value !~ /^0(x|b|o)/
    end

    private def underscored(raw_number)
      sign, value, fraction, suffix = parse_number raw_number
      value = slice_digits(value.reverse) { |slice| slice }.reverse
      fraction = "." + slice_digits(fraction) { |slice| slice } if fraction

      "#{sign}#{value}#{fraction}#{suffix}"
    end

    private def slice_digits(value, by = 3)
      ([] of String).tap do |slices|
        value.chars.reject(&.== '_').each_slice(by) do |slice|
          slices << (yield slice).join
        end
      end.join("_")
    end

    private def parse_number(value)
      value, sign = parse_sign(value)
      value, suffix = parse_suffix(value)
      value, fraction = parse_fraction(value)

      {sign, value, fraction, suffix}
    end

    private def parse_sign(value)
      if "+-".includes?(value[0])
        sign = value[0]
        value = value[1..-1]
      end
      {value, sign}
    end

    private def parse_suffix(value)
      if pos = (value =~ /e/ || value =~ /_(i|u|f)/)
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
