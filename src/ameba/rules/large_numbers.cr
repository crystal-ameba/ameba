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
  # ```
  #
  # And has to be rewritten as the following:
  #
  # ```
  # 10_000
  # 141_592_654
  # ```
  #
  struct LargeNumbers < Rule
    def test(source)
      lexer = source.lexer
      while (token = lexer.next_token).type != :EOF
        next unless token.type == :NUMBER && decimal?(token.raw)

        if (expected = underscored_value(*parse_number(token.raw))) != token.raw
          source.error self, token.line_number,
            "Large numbers should be written with underscores: #{expected}"
        end
      end
    end

    private def decimal?(value)
      value !~ /^0(x|b|o)/
    end

    private def underscored_value(sign, value, fraction, suffix)
      value = ([] of String).tap do |parts|
        value.to_s.reverse.chars.reject(&.== '_').each_slice(3) { |s| parts << s.reverse.join }
      end.reverse.join("_")

      fraction = ([] of String).tap do |parts|
        fraction.to_s.chars.reject(&.== '_').each_slice(3) { |s| parts << s.join }
      end.join("_")

      fraction = ".#{fraction}" unless fraction.to_s.empty?

      "#{sign}#{value}#{fraction}#{suffix}"
    end

    # Detects parts of the number.
    # Each number may consist of the following parts:
    # sign, value, fraction, suffix
    #
    # ```
    # -100_i32
    # ```
    #
    #  sign: -
    #  value: 100
    #  fraction: nil
    #  suffix: _i32
    #
    # ```
    # 100.111_f32
    # ```
    #
    # sign: nil
    # value: 100
    # fraction: 111
    # suffix: _f32
    #
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
