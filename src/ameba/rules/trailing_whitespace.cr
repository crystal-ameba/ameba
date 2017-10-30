module Ameba::Rules
  # A rule that disallows trailing whitespace at the end of a line.
  struct TrailingWhitespace < Rule
    def test(source)
      source.lines.each_with_index do |line, index|
        next unless line =~ /\s$/
        source.error self, index + 1, "Trailing whitespace detected"
      end
    end
  end
end
