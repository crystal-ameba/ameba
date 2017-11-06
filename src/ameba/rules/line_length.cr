module Ameba::Rules
  # A rule that disallows lines longer than 80 symbols.
  #
  struct LineLength < Rule
    def test(source)
      source.lines.each_with_index do |line, index|
        next unless line.size > 80
        source.error self, index + 1,
          "Line too long (#{line.size} symbols)"
      end
    end
  end
end
