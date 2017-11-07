module Ameba::Rules
  # A rule that disallows trailing whitespaces.
  #
  struct TrailingWhitespace < Rule
    def test(source)
      source.lines.each_with_index do |line, index|
        next unless line =~ /\s$/
        source.error self, source.location(index + 1, line.size),
          "Trailing whitespace detected"
      end
    end
  end
end
