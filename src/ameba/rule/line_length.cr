module Ameba::Rule
  # A rule that disallows lines longer than 80 symbols.
  #
  struct LineLength < Base
    def test(source)
      source.lines.each_with_index do |line, index|
        next unless line.size > 80

        source.error self, source.location(index + 1, line.size),
          "Line too long"
      end
    end
  end
end
